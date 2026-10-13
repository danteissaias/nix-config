/**
 * Parallel web search for pi.
 *
 * Registers two tools that call the Parallel API (https://docs.parallel.ai) directly:
 * - web_search: POST /v1/search
 * - web_fetch:  POST /v1/extract
 *
 * API key: 1Password item "Parallel" (field "credential"), read with `op read` by vault and item ID.
 * The key is read once, when a tool first runs, and kept in memory for the process.
 *
 * Other settings:
 * - PI_PARALLEL_SEARCH_MODE: default search mode (turbo, fast, basic, advanced). Default: fast.
 */

import { execFile } from "node:child_process";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { StringEnum, Type } from "@earendil-works/pi-ai";
import {
	DEFAULT_MAX_BYTES,
	DEFAULT_MAX_LINES,
	type ExtensionAPI,
	type ExtensionContext,
	formatSize,
	truncateHead,
} from "@earendil-works/pi-coding-agent";

const API_BASE = "https://api.parallel.ai";
// Vault and item IDs do not change when the vault or item is renamed.
const OP_REF = "op://g27jwq6n4d7mhtrjtxpqpls4bi/jkfisraoxtq4gfczuvvlnidk7i/credential";
const SEARCH_MODES = ["turbo", "fast", "basic", "advanced"] as const;
type SearchMode = (typeof SEARCH_MODES)[number];
const REQUEST_TIMEOUT_MS = 60_000;
const FULL_CONTENT_MAX_CHARS = 40_000;

// ---------------------------------------------------------------------------
// API key

let cachedKey: string | undefined;
let pendingKey: Promise<string> | undefined;

function opRead(ref: string): Promise<string> {
	return new Promise((resolve, reject) => {
		execFile("op", ["read", "--no-newline", ref], { timeout: 60_000 }, (err, stdout, stderr) => {
			if (err) {
				const detail = (stderr || err.message).trim();
				reject(new Error(`1Password lookup failed for ${ref}: ${detail}`));
				return;
			}
			resolve(stdout.trim());
		});
	});
}

async function getApiKey(): Promise<string> {
	if (cachedKey) return cachedKey;
	pendingKey ??= opRead(OP_REF)
		.then((key) => {
			if (!key) throw new Error("1Password returned an empty Parallel API key");
			cachedKey = key;
			return key;
		})
		.finally(() => {
			pendingKey = undefined;
		});
	try {
		return await pendingKey;
	} catch (err) {
		throw new Error(`No Parallel API key. Store it in 1Password at ${OP_REF}. ${(err as Error).message}`);
	}
}

// ---------------------------------------------------------------------------
// HTTP

let sessionId: string | undefined;

async function post<T>(path: string, body: Record<string, unknown>, signal: AbortSignal | undefined): Promise<T> {
	const key = await getApiKey();
	const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
	const res = await fetch(`${API_BASE}${path}`, {
		method: "POST",
		headers: { "content-type": "application/json", "x-api-key": key },
		body: JSON.stringify(body),
		signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
	});
	const text = await res.text();
	if (!res.ok) {
		let message = text.slice(0, 1000);
		try {
			const parsed = JSON.parse(text) as { message?: string; error?: { message?: string; detail?: unknown } };
			if (parsed.error?.message) {
				message = parsed.error.message;
				if (parsed.error.detail) message += ` ${JSON.stringify(parsed.error.detail).slice(0, 800)}`;
			} else if (parsed.message) {
				message = parsed.message;
			}
		} catch {
			// Keep the raw text.
		}
		if (res.status === 401 || res.status === 403) cachedKey = undefined;
		throw new Error(`Parallel ${path} failed with HTTP ${res.status}: ${message}`);
	}
	const data = JSON.parse(text) as T & { session_id?: string };
	if (data.session_id) sessionId = data.session_id;
	return data;
}

function clientModel(ctx: ExtensionContext): string | undefined {
	return ctx.model?.id;
}

function compact<T extends Record<string, unknown>>(value: T): Partial<T> {
	return Object.fromEntries(
		Object.entries(value).filter(([, v]) => v !== undefined && !(Array.isArray(v) && v.length === 0)),
	) as Partial<T>;
}

// ---------------------------------------------------------------------------
// Output

async function finishText(text: string, prefix: string): Promise<{ text: string; fullOutputPath?: string }> {
	const truncation = truncateHead(text, { maxLines: DEFAULT_MAX_LINES, maxBytes: DEFAULT_MAX_BYTES });
	if (!truncation.truncated) return { text };
	const dir = await mkdtemp(join(tmpdir(), `pi-${prefix}-`));
	const file = join(dir, "output.md");
	await writeFile(file, text, "utf8");
	return {
		text:
			`${truncation.content}\n\n[Output truncated: showing ${truncation.outputLines} of ${truncation.totalLines} lines ` +
			`(${formatSize(truncation.outputBytes)} of ${formatSize(truncation.totalBytes)}). Full output: ${file}]`,
		fullOutputPath: file,
	};
}

function formatWarnings(warnings: ParallelWarning[] | null | undefined): string {
	if (!warnings?.length) return "";
	return `\nWarnings:\n${warnings.map((w) => `- ${w.type}: ${w.message}`).join("\n")}\n`;
}

// ---------------------------------------------------------------------------
// Parallel types

interface ParallelWarning {
	type: string;
	message: string;
}

interface SearchResponse {
	search_id: string;
	session_id: string;
	results: { url: string; title?: string | null; publish_date?: string | null; excerpts?: string[] }[];
	warnings?: ParallelWarning[] | null;
}

interface ExtractResponse {
	extract_id: string;
	session_id: string;
	results: {
		url: string;
		title?: string | null;
		publish_date?: string | null;
		excerpts?: string[] | null;
		full_content?: string | null;
	}[];
	errors: { url: string; error_type: string; http_status_code?: number | null; content?: string | null }[];
	warnings?: ParallelWarning[] | null;
}

// ---------------------------------------------------------------------------
// Schemas

const SearchParams = Type.Object({
	objective: Type.String({
		description:
			"Self-contained natural-language description of what you need to find, with context. Say what makes a result useful, for example 'official docs', 'the most recent release and its date', or 'news from this week'.",
	}),
	search_queries: Type.Array(Type.String(), {
		minItems: 1,
		maxItems: 5,
		description: "2-3 short keyword queries of 3-6 words each. Use different wording in each query.",
	}),
	mode: Type.Optional(
		StringEnum(SEARCH_MODES, {
			description:
				"turbo: fastest. fast (default): good quality, under 1 s. basic: longer excerpts, about 1 s. advanced: best quality for hard or multi-hop questions, about 3 s or more.",
		}),
	),
	max_results: Type.Optional(Type.Integer({ minimum: 1, maximum: 20, description: "Default 10." })),
	include_domains: Type.Optional(
		Type.Array(Type.String(), { description: "Only return results from these domains, for example ['docs.python.org']." }),
	),
	exclude_domains: Type.Optional(Type.Array(Type.String(), { description: "Never return results from these domains." })),
	after_date: Type.Optional(
		Type.String({ description: "Only return content published on or after this date (YYYY-MM-DD). Use for recent news." }),
	),
});

const SearchOutput = Type.Object({
	search_id: Type.String(),
	results: Type.Array(
		Type.Object({
			url: Type.String(),
			title: Type.Union([Type.String(), Type.Null()]),
			publish_date: Type.Union([Type.String(), Type.Null()]),
			excerpts: Type.Array(Type.String()),
		}),
	),
});

const FetchParams = Type.Object({
	urls: Type.Array(Type.String(), { minItems: 1, maxItems: 20, description: "Public URLs to read (up to 20)." }),
	objective: Type.Optional(
		Type.String({
			description: "What you need from the pages. Excerpts focus on it. Recommended unless you need the full page.",
		}),
	),
	full_content: Type.Optional(
		Type.Boolean({
			description: `Return the full page as markdown (up to ${FULL_CONTENT_MAX_CHARS} chars per page) instead of excerpts only. Default false.`,
		}),
	),
});

const FetchOutput = Type.Object({
	extract_id: Type.String(),
	results: Type.Array(
		Type.Object({
			url: Type.String(),
			title: Type.Union([Type.String(), Type.Null()]),
			publish_date: Type.Union([Type.String(), Type.Null()]),
			excerpts: Type.Array(Type.String()),
			full_content: Type.Union([Type.String(), Type.Null()]),
		}),
	),
	errors: Type.Array(Type.Object({ url: Type.String(), error: Type.String() })),
});

// ---------------------------------------------------------------------------
// Extension

function defaultMode(): SearchMode {
	const value = process.env.PI_PARALLEL_SEARCH_MODE?.trim().toLowerCase();
	return (SEARCH_MODES as readonly string[]).includes(value ?? "") ? (value as SearchMode) : "fast";
}

export default function parallelWebSearch(pi: ExtensionAPI): void {
	pi.registerTool({
		name: "web_search",
		label: "Web search",
		description:
			"Search the public web with Parallel. Returns ranked URLs with dated, relevant excerpts. " +
			"Always give a clear objective and 2-3 different keyword queries. " +
			"For 'latest' or 'current' questions, put that need in the objective, and use after_date if it helps. " +
			"Excerpts can be out of date: check publish dates, and use web_fetch on the best source to confirm important facts.",
		promptSnippet: "web_search: search the web (Parallel) for current or online information",
		promptGuidelines: [
			"Use web_search when the user asks for current or online information, or when freshness matters. Do not guess.",
			"Use web_fetch to read a known URL, or to confirm a fact from a search result before you rely on it.",
		],
		parameters: SearchParams,
		outputSchema: SearchOutput,
		annotations: { readOnlyHint: true, openWorldHint: true },

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const mode = params.mode ?? defaultMode();
			const sourcePolicy = compact({
				include_domains: params.include_domains,
				exclude_domains: params.exclude_domains,
				after_date: params.after_date,
			});
			const advanced = compact({
				max_results: params.max_results,
				source_policy: Object.keys(sourcePolicy).length ? sourcePolicy : undefined,
			});
			const data = await post<SearchResponse>(
				"/v1/search",
				compact({
					objective: params.objective,
					search_queries: params.search_queries,
					mode,
					session_id: sessionId,
					client_model: clientModel(ctx),
					advanced_settings: Object.keys(advanced).length ? advanced : undefined,
				}),
				signal,
			);

			const results = data.results.map((r) => ({
				url: r.url,
				title: r.title ?? null,
				publish_date: r.publish_date ?? null,
				excerpts: r.excerpts ?? [],
			}));

			let text = results.length ? "" : "No results.\n";
			results.forEach((r, i) => {
				text += `## ${i + 1}. ${r.title ?? r.url}\nURL: ${r.url}\n`;
				if (r.publish_date) text += `Published: ${r.publish_date}\n`;
				text += `\n${r.excerpts.join("\n\n")}\n\n`;
			});
			text += formatWarnings(data.warnings);
			const out = await finishText(text.trimEnd(), "web-search");

			return {
				content: [{ type: "text", text: out.text }],
				structuredContent: { search_id: data.search_id, results },
				details: { mode, queries: params.search_queries, count: results.length, fullOutputPath: out.fullOutputPath },
			};
		},
	});

	pi.registerTool({
		name: "web_fetch",
		label: "Web fetch",
		description:
			"Read one or more public web pages with Parallel Extract. Returns excerpts focused on the objective, or the full page as markdown when full_content is true.",
		promptSnippet: "web_fetch: read public web pages (Parallel)",
		parameters: FetchParams,
		outputSchema: FetchOutput,
		annotations: { readOnlyHint: true, openWorldHint: true },

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const fullContent = params.full_content === true;
			const data = await post<ExtractResponse>(
				"/v1/extract",
				compact({
					urls: params.urls,
					objective: params.objective,
					session_id: sessionId,
					client_model: clientModel(ctx),
					advanced_settings: fullContent
						? { full_content: { max_chars_per_result: FULL_CONTENT_MAX_CHARS } }
						: undefined,
				}),
				signal,
			);

			const results = data.results.map((r) => ({
				url: r.url,
				title: r.title ?? null,
				publish_date: r.publish_date ?? null,
				excerpts: r.excerpts ?? [],
				full_content: r.full_content ?? null,
			}));
			const errors = data.errors.map((e) => ({
				url: e.url,
				error: `${e.error_type}${e.http_status_code ? ` (HTTP ${e.http_status_code})` : ""}${e.content ? `: ${e.content.slice(0, 300)}` : ""}`,
			}));

			let text = "";
			for (const r of results) {
				text += `## ${r.title ?? r.url}\nURL: ${r.url}\n`;
				if (r.publish_date) text += `Published: ${r.publish_date}\n`;
				text += `\n${r.full_content ?? r.excerpts.join("\n\n")}\n\n`;
			}
			if (errors.length) text += `Errors:\n${errors.map((e) => `- ${e.url}: ${e.error}`).join("\n")}\n`;
			text += formatWarnings(data.warnings);
			const out = await finishText(text.trimEnd() || "No content.", "web-fetch");

			return {
				content: [{ type: "text", text: out.text }],
				structuredContent: { extract_id: data.extract_id, results, errors },
				details: { urls: params.urls, count: results.length, errors: errors.length, fullOutputPath: out.fullOutputPath },
			};
		},
	});
}
