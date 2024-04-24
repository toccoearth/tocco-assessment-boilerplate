CREATE EXTENSION IF NOT EXISTS "moddatetime" WITH SCHEMA "extensions";

CREATE EXTENSION IF NOT EXISTS "vector" WITH SCHEMA "extensions";

-- items & private_items are not very useful - can be deleted later
CREATE TABLE IF NOT EXISTS public.items (
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name character varying not null,
  description character varying not null
);

CREATE TABLE IF NOT EXISTS public.private_items (
  created_at timestamp WITH time zone NOT NULL DEFAULT NOW(),
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  name character varying NOT NULL,
  description character varying NOT NULL
);

-- 1. Enable RLS
ALTER TABLE
  public.private_items ENABLE ROW LEVEL SECURITY;

-- 2. Create Policy for SELECT
CREATE POLICY select_all_policy ON public.private_items FOR
SELECT
  USING (TRUE);

-- 3. Create Policy for INSERT
CREATE POLICY insert_auth_policy ON public.private_items FOR
INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Create Policy for UPDATE
CREATE POLICY update_auth_policy ON public.private_items FOR
UPDATE
  USING (auth.uid() = id);

--- tocco setup
create table public.organizations (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name character varying not null,
  contact_phone text null,
  contact_email text null,
  website character varying null,
  linkedin character varying null,
  created_at timestamp with time zone null default (now() at time zone 'utc' :: text),
  updated_at timestamp with time zone null default (now() at time zone 'utc' :: text),
  uuid uuid not null default uuid_generate_v4 (),
  description character varying null,
  logo text null,
  images text [] null,
  slug text not null
);

create trigger handle_updated_at before
update
  on organizations for each row execute function moddatetime ('updated_at');

create table public.documents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default (now() at time zone 'utc' :: text),
  file_name character varying null,
  file_description character varying null,
  file_path character varying null,
  organization_id bigint null,
  document_type text,
  FOREIGN KEY ("organization_id") REFERENCES public.organizations("id") ON DELETE CASCADE
);

create index if not exists idx_document_organization_id on public.documents using btree (organization_id) tablespace pg_default;

create trigger handle_updated_at before
update
  on documents for each row execute function moddatetime ('updated_at');

CREATE TABLE document_embeddings(
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  uuid uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'utc' :: "text"),
  updated_at timestamp without time zone DEFAULT ("now"() AT TIME ZONE 'utc' :: "text"),
  content text,
  embedding vector,
  metadata jsonb,
  document_id bigint null,
  FOREIGN KEY ("document_id") REFERENCES public.documents("id") ON DELETE CASCADE
);

CREATE TRIGGER "handle_updated_at" BEFORE
UPDATE
  ON "public"."document_embeddings" FOR EACH ROW EXECUTE FUNCTION "extensions"."moddatetime"('updated_at');

CREATE OR REPLACE FUNCTION match_documents(query_embedding vector(1536), match_count int DEFAULT NULL, FILTER jsonb DEFAULT '{}')
  RETURNS TABLE(
    uuid uuid,
    content text,
    metadata jsonb,
    embedding jsonb,
    similarity float)
  LANGUAGE plpgsql
  AS $$
  # variable_conflict use_column
BEGIN
  RETURN query
  SELECT
    uuid,
    content,
    metadata,
(embedding::text)::jsonb AS embedding,
    1 -(document_embedding.embedding <=> query_embedding) AS similarity
  FROM
    document_embedding
  WHERE
    metadata @> FILTER
  ORDER BY
    document_embedding.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

ALTER TABLE
  "public"."documents" ENABLE ROW LEVEL SECURITY;

ALTER TABLE
  "public"."documents" OWNER TO "postgres";

ALTER TABLE
  "public"."document_embeddings" ENABLE ROW LEVEL SECURITY;

ALTER TABLE
  "public"."document_embeddings" OWNER TO "postgres";

ALTER TABLE
  "public"."organizations" ENABLE ROW LEVEL SECURITY;

ALTER TABLE
  "public"."organizations" OWNER TO "postgres";