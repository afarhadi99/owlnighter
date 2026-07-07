/**
 * JobQueue — the enqueue seam the API/handlers call.
 *
 * In production this is backed by Cloud Tasks (GCP) or Inngest (durable JS
 * workflows). Those adapters live behind the same interface so callers never
 * change. The in-memory queue below is for local dev and tests only.
 */
export interface Job {
  name: string;
  payload: unknown;
  enqueuedAt: string;
}

export interface JobQueue {
  enqueue(name: string, payload: unknown): Promise<void>;
}

export interface InMemoryQueue extends JobQueue {
  /** All jobs enqueued so far — inspect in tests / dev. */
  readonly jobs: readonly Job[];
  /** Pop everything for a manual drain in dev. */
  drain(): Job[];
}

/** Dev/test queue. Not durable — do NOT use in production. */
export function createInMemoryQueue(): InMemoryQueue {
  const jobs: Job[] = [];
  return {
    get jobs() {
      return jobs;
    },
    async enqueue(name, payload) {
      jobs.push({ name, payload, enqueuedAt: new Date().toISOString() });
    },
    drain() {
      return jobs.splice(0, jobs.length);
    },
  };
}
