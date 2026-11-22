import { useEffect, useEffectEvent, useRef, useState } from 'react';

const followedKey = 'stockpilot.followedForecastJob';
const displayedKey = 'stockpilot.displayedForecastJob';
export const isActive = job => job.status === 'queued' || job.status === 'running';

function sessionValue(key, value) {
  try {
    if (value === undefined) return sessionStorage.getItem(key);
    if (value === null) sessionStorage.removeItem(key);
    else sessionStorage.setItem(key, value);
  } catch { /* Storage may be unavailable in a private browsing session. */ }
  return null;
}

export const displayedJob = value => sessionValue(displayedKey, value);

export async function request(path, signal, options) {
  const response = await fetch(path, { cache: 'no-store', ...options, signal });
  let data;
  try { data = await response.json(); }
  catch { throw new Error('The local forecast service could not read this request.'); }
  if (!response.ok) {
    const error = new Error(data.error || 'The local forecast request failed.');
    error.status = response.status;
    throw error;
  }
  return data;
}

function useQueuePolling(revision, onUpdate, onError) {
  const update = useEffectEvent(onUpdate);
  const reportError = useEffectEvent(onError);
  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    let timer;
    async function poll() {
      let interval = 5000;
      try {
        const { jobs } = await request('/api/forecast?queue=1', signal);
        if (signal.aborted) return;
        await update(jobs, signal);
        if (jobs.some(isActive)) interval = 900;
      } catch (error) {
        if (!signal.aborted) reportError(error.message);
      }
      if (!signal.aborted) timer = setTimeout(poll, interval);
    }
    poll();
    return () => { controller.abort(); clearTimeout(timer); };
  }, [revision]);
}

export default function useForecastQueue(onFinished) {
  const [jobs, setJobs] = useState(null);
  const [queueError, setQueueError] = useState('');
  const [revision, setRevision] = useState(0);
  const followed = useRef(null);
  useEffect(() => {
    const id = sessionValue(followedKey);
    if (id) followed.current = { id, restored: true };
  }, []);

  function follow(id) {
    followed.current = id ? { id, restored: false } : null;
    sessionValue(followedKey, id);
  }
  function accepted(job) {
    follow(job.id);
    setJobs(current => {
      const others = (current ?? []).filter(entry => entry.id !== job.id);
      return [...others.filter(isActive), job, ...others.filter(entry => !isActive(entry))];
    });
    setQueueError('');
    setRevision(value => value + 1);
  }
  useQueuePolling(revision, async (rows, signal) => {
    setJobs(rows);
    setQueueError('');
    const target = followed.current;
    if (!target) return;
    let job = rows.find(entry => entry.id === target.id);
    if (!job) {
      try { ({ job } = await request('/api/forecast?job=' + encodeURIComponent(target.id), signal)); }
      catch (error) {
        if (error.status !== 404) throw error;
        if (!signal.aborted && followed.current === target) follow(null);
        return;
      }
    }
    if (!signal.aborted && followed.current === target && !isActive(job)) {
      follow(null);
      onFinished(job, target.restored);
    }
  }, setQueueError);
  return { jobs, queueError, accepted, forget: () => follow(null) };
}
