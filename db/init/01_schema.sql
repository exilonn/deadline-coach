-- Project database for Deadline Coach.
-- Run automatically by the postgres container on its first start,
-- or paste the part after "\c" into the Supabase SQL Editor.

create database deadline_coach;
\c deadline_coach

create table deadlines (
  id          bigint generated always as identity primary key,
  chat_id     bigint not null,
  source      text not null default 'manual' check (source in ('manual','moodle')),
  moodle_uid  text unique,
  course      text not null,
  title       text not null,
  due_at      timestamptz not null,
  weight_pct  numeric,
  est_hours   numeric,
  status      text not null default 'open' check (status in ('open','done')),
  reminded_7  boolean not null default false,
  reminded_3  boolean not null default false,
  reminded_1  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table sync_log (
  id        bigint generated always as identity primary key,
  run_at    timestamptz not null default now(),
  fetched   int,
  inserted  int,
  moved     int,
  error     text
);
