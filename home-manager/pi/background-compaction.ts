/**
 * Background compaction for pi: a rolling summary that is kept up to date while the agent works.
 *
 * Ideas from:
 * - opencode background compaction: https://github.com/sst/opencode/pull/57444
 * - APEC, asynchronous progressive compaction:
 *   https://www.microsoft.com/en-us/research/publication/benchmarking-long-horizon-agent-context-compaction-with-compactionbench/
 * - Claude Code session memory: https://ascl1u.github.io/blog/claude-code-context-management
 * - Factory anchored iterative summaries: https://factory.ai/news/compressing-context
 *
 * How it works:
 * - When the context passes START_RATIO of the auto-compaction threshold, a background call
 *   summarizes the older messages with pi's own summary prompt. The summary is "anchored" at the
 *   first message it does not cover.
 * - Each time STEP_RATIO of the threshold more becomes old enough to summarize, a background call
 *   merges only that new span into the summary (pi's update prompt, `previousSummary`).
 * - When pi compacts, `session_before_compact` waits for a call that is still running, summarizes
 *   the small span between the anchor and pi's own cut point, and returns the result. pi keeps the
 *   same recent messages it keeps by default.
 * - When the summary does not apply (other branch, other compaction, custom instructions,
 *   overflow), pi compacts as usual.
 *
 * Limits:
 * - State lives in memory. A restart or reload starts again from the last compaction.
 * - Background work that is never used is not counted in the session totals.
 */

import type { Usage } from "@earendil-works/pi-ai";
import {
	buildSessionProjection,
	type CompactionEntry,
	type ExtensionAPI,
	type ExtensionContext,
	estimateTokens,
	generateSummaryWithUsage,
	getLatestCompactionEntry,
	type ProjectedSessionEntry,
	type SessionEntry,
	SettingsManager,
} from "@earendil-works/pi-coding-agent";

/** Share of the threshold (contextWindow - reserveTokens) at which the first background summary starts. */
const START_RATIO = 0.5;
/** Share of the threshold of new old-enough messages that starts the next background update. */
const STEP_RATIO = 0.1;
/** Failed background updates in a row after which none starts again until the next compaction. */
const MAX_FAILURES = 2;

type Rolling = {
	/** Latest compaction entry this summary builds on, or null for none. */
	baseId: string | null;
	/** Covers every message before `anchorId`. Starts as the base compaction's summary. */
	summary: string | undefined;
	/** First entry the summary does not cover. */
	anchorId: string;
	/** True once at least one update completed. */
	updated: boolean;
	usage: Usage | undefined;
	failures: number;
	running?: { controller: AbortController; promise: Promise<void> };
};

const tokensOf = (entries: ProjectedSessionEntry[]) =>
	entries.reduce((sum, entry) => sum + entry.messages.reduce((s, m) => s + estimateTokens(m), 0), 0);

/** System messages are prompt state, not conversation. pi leaves them out of summaries too. */
const messagesOf = (entries: ProjectedSessionEntry[]): ProjectedSessionEntry["messages"] =>
	entries.flatMap((entry) => entry.messages.filter((message) => message.role !== "system"));

/** An entry the kept messages can start at: not a tool result, which must stay with its call. */
const isCutPoint = (entry: ProjectedSessionEntry) =>
	entry.sourceEntry.type !== "compaction" &&
	entry.messages.some((message) => message.role !== "toolResult" && message.role !== "system");

const addUsage = (a: Usage | undefined, b: Usage): Usage =>
	!a
		? b
		: {
				...a,
				input: a.input + b.input,
				output: a.output + b.output,
				cacheRead: a.cacheRead + b.cacheRead,
				cacheWrite: a.cacheWrite + b.cacheWrite,
				totalTokens: a.totalTokens + b.totalTokens,
				cost: {
					input: a.cost.input + b.cost.input,
					output: a.cost.output + b.cost.output,
					cacheRead: a.cost.cacheRead + b.cost.cacheRead,
					cacheWrite: a.cost.cacheWrite + b.cost.cacheWrite,
					total: a.cost.total + b.cost.total,
				},
			};

/** The projected conversation since the latest compaction, and that compaction. */
const view = (branch: SessionEntry[]) => {
	const entries = buildSessionProjection(branch).entries;
	const base = getLatestCompactionEntry(branch);
	// The newest compaction is projected first; its kept messages follow it.
	const start = entries[0]?.sourceEntry.type === "compaction" ? 1 : 0;
	return { entries, base, start };
};

export default function (pi: ExtensionAPI) {
	let rolling: Rolling | undefined;

	const reset = () => {
		rolling?.running?.controller.abort();
		rolling = undefined;
	};

	/** The rolling summary for this branch, made new when the base compaction or the branch changed. */
	const current = (branch: SessionEntry[]) => {
		const { entries, base, start } = view(branch);
		const baseId = base?.id ?? null;
		const anchor = rolling && entries.findIndex((entry) => entry.sourceEntry.id === rolling?.anchorId);
		if (!rolling || rolling.baseId !== baseId || anchor === undefined || anchor < start) {
			reset();
			const first = entries[start];
			if (!first) return undefined;
			rolling = {
				baseId,
				summary: base?.summary,
				anchorId: first.sourceEntry.id,
				updated: false,
				usage: undefined,
				failures: 0,
			};
		}
		const r = rolling as Rolling;
		return { r, entries, anchor: entries.findIndex((entry) => entry.sourceEntry.id === r.anchorId) };
	};

	/** Merges `span` into the summary and moves the anchor to `nextAnchorId`. Throws on failure. */
	const update = async (
		ctx: ExtensionContext,
		r: Rolling,
		span: ProjectedSessionEntry[],
		nextAnchorId: string,
		signal: AbortSignal,
	) => {
		const model = ctx.model;
		if (!model) throw new Error("No model selected");
		// apiKey is undefined: modelRegistry.streamSimple resolves auth and routes virtual models.
		const result = await generateSummaryWithUsage(
			messagesOf(span),
			model,
			undefined,
			undefined,
			undefined,
			signal,
			undefined,
			r.summary,
			ctx.thinkingLevel,
			(...args: Parameters<typeof ctx.modelRegistry.streamSimple>) => ctx.modelRegistry.streamSimple(...args),
		);
		if (signal.aborted) throw new Error("aborted");
		r.summary = result.text;
		r.anchorId = nextAnchorId;
		r.updated = true;
		r.usage = addUsage(r.usage, result.usage);
	};

	pi.on("turn_end", (_event, ctx) => {
		const usage = ctx.getContextUsage();
		if (!ctx.model || !usage?.tokens) return;
		const settings = SettingsManager.create(ctx.cwd, undefined, {
			projectTrusted: ctx.isProjectTrusted(),
		}).getCompactionSettings(ctx.model);
		if (!settings.enabled) return;
		const threshold = usage.contextWindow - settings.reserveTokens;
		if (threshold <= 0 || usage.tokens < threshold * START_RATIO) return;

		const state = current(ctx.sessionManager.getBranch());
		if (!state || state.anchor < 0) return;
		const { r, entries, anchor } = state;
		if (r.running || r.failures >= MAX_FAILURES) return;

		// Cut where at least keepRecentTokens of recent messages stay after it, as pi does.
		let kept = 0;
		let cut = entries.length;
		for (let i = entries.length - 1; i > anchor && kept < settings.keepRecentTokens; i--) {
			kept += tokensOf([entries[i]]);
			cut = i;
		}
		if (cut >= entries.length) return;
		while (cut > anchor && !isCutPoint(entries[cut])) cut--;
		if (cut <= anchor) return;
		const span = entries.slice(anchor, cut);
		if (tokensOf(span) < threshold * STEP_RATIO) return;

		const controller = new AbortController();
		const promise = update(ctx, r, span, entries[cut].sourceEntry.id, controller.signal)
			.then(() => {
				r.failures = 0;
			})
			.catch(() => {
				if (!controller.signal.aborted) r.failures++;
			})
			.finally(() => {
				if (r.running?.controller === controller) r.running = undefined;
			});
		r.running = { controller, promise };
	});

	pi.on("session_before_compact", async (event, ctx) => {
		const { preparation, branchEntries, reason, customInstructions, signal } = event;
		const r = rolling;
		if (!r?.updated || reason === "overflow" || customInstructions) return;

		const onAbort = () => r.running?.controller.abort();
		signal.addEventListener("abort", onAbort, { once: true });
		try {
			await r.running?.promise;
			if (signal.aborted || rolling !== r) return;

			const state = current(branchEntries);
			if (!state || state.r !== r || state.anchor < 0) return;
			const { entries, anchor } = state;
			const cut = entries.findIndex((entry) => entry.sourceEntry.id === preparation.firstKeptEntryId);
			// Summarize the rest up to pi's cut point. That span is small when the summary kept up.
			if (cut > anchor) await update(ctx, r, entries.slice(anchor, cut), preparation.firstKeptEntryId, signal);

			// pi only carries file lists forward from its own compactions, so add the previous ones here.
			const previous = getLatestCompactionEntry(branchEntries) as CompactionEntry<{
				readFiles?: string[];
				modifiedFiles?: string[];
			}> | null;
			const modified = new Set([
				...preparation.fileOps.edited,
				...preparation.fileOps.written,
				...(previous?.details?.modifiedFiles ?? []),
			]);
			const read = new Set([...preparation.fileOps.read, ...(previous?.details?.readFiles ?? [])]);
			const readFiles = [...read].filter((file) => !modified.has(file)).sort();
			const modifiedFiles = [...modified].sort();
			const sections = [
				readFiles.length ? `<read-files>\n${readFiles.join("\n")}\n</read-files>` : "",
				modifiedFiles.length ? `<modified-files>\n${modifiedFiles.join("\n")}\n</modified-files>` : "",
			].filter(Boolean);
			// An earlier summary may carry file lists already; keep only the new ones.
			const text = (r.summary ?? "").replace(/\n*<(read|modified)-files>[\s\S]*?<\/\1-files>/g, "").trimEnd();

			return {
				compaction: {
					summary: sections.length ? `${text}\n\n${sections.join("\n\n")}` : text,
					firstKeptEntryId: r.anchorId,
					tokensBefore: preparation.tokensBefore,
					usage: r.usage,
					details: { readFiles, modifiedFiles },
				},
			};
		} catch {
			return;
		} finally {
			signal.removeEventListener("abort", onAbort);
		}
	});

	pi.on("session_compact", () => reset());
	pi.on("session_shutdown", () => reset());
}
