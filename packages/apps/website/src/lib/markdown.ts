// Import generated docs at build time
import docsData from '../generated/docs.json';

export interface DocMetadata {
  title: string;
  description?: string;
  order?: number;
}

export interface Doc {
  slug: string;
  metadata: DocMetadata;
  content: string;
}

const { docs, guides } = docsData as { docs: Doc[], guides: Doc[] };

export function getDocBySlug(slug: string, type: 'docs' | 'guides' = 'docs'): Doc | null {
  const list = type === 'guides' ? guides : docs;
  return list.find(d => d.slug === slug) || null;
}

export function getAllDocs(type: 'docs' | 'guides' = 'docs'): Doc[] {
  return type === 'guides' ? guides : docs;
}

export function getDocSlugs(type: 'docs' | 'guides' = 'docs'): string[] {
  const list = type === 'guides' ? guides : docs;
  return list.map(d => d.slug);
}
