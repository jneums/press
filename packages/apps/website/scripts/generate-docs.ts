import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';
import { remark } from 'remark';
import html from 'remark-html';
import remarkGfm from 'remark-gfm';
import Prism from 'prismjs';
import 'prismjs/components/prism-typescript';
import 'prismjs/components/prism-javascript';
import 'prismjs/components/prism-json';
import 'prismjs/components/prism-bash';
import 'prismjs/components/prism-markdown';

// Add Motoko language support
Prism.languages.motoko = {
  'comment': [
    {
      pattern: /(^|[^\\])\/\*[\s\S]*?(?:\*\/|$)/,
      lookbehind: true
    },
    {
      pattern: /(^|[^\\:])\/\/.*/,
      lookbehind: true
    }
  ],
  'string': {
    pattern: /"(?:\\.|[^\\"\r\n])*"/,
    greedy: true
  },
  'keyword': /\b(?:actor|and|async|assert|await|break|case|catch|class|continue|debug|debug_show|do|else|false|for|func|if|ignore|import|in|module|not|null|object|or|label|let|loop|private|public|return|shared|stable|switch|system|throw|true|try|type|var|while|query)\b/,
  'function': /\b\w+(?=\s*\()/,
  'number': /\b0x[\da-f]+\b|(?:\b\d+(?:\.\d*)?|\B\.\d+)(?:e[+-]?\d+)?/i,
  'operator': /[<>]=?|[!=]=?=?|--?|\+\+?|&&?|\|\|?|[?*/~^%]/,
  'punctuation': /[{}[\];(),.:]/
};

Prism.languages.mo = Prism.languages.motoko;

const docsDirectory = path.join(process.cwd(), '..', '..', '..', 'docs');
const guidesDirectory = path.join(process.cwd(), '..', '..', '..', 'guides');

interface DocMetadata {
  title: string;
  description?: string;
  order?: number;
}

interface Doc {
  slug: string;
  metadata: DocMetadata;
  content: string;
}

async function processDoc(filePath: string, slug: string): Promise<Doc> {
  const fileContents = fs.readFileSync(filePath, 'utf8');
  const { data, content } = matter(fileContents);

  const processedContent = await remark()
    .use(remarkGfm)
    .use(html, { sanitize: false })
    .process(content);
  let contentHtml = processedContent.toString();
  
  // Apply syntax highlighting
  contentHtml = contentHtml.replace(
    /<pre><code(?:\s+class="language-(\w+)")?>([\s\S]*?)<\/code><\/pre>/g,
    (match, lang, code) => {
      const decodedCode = code
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'");
      
      if (lang && Prism.languages[lang]) {
        const highlighted = Prism.highlight(decodedCode, Prism.languages[lang], lang);
        return `<pre class="language-${lang}"><code class="language-${lang}">${highlighted}</code></pre>`;
      }
      return `<pre><code>${code}</code></pre>`;
    }
  );

  return {
    slug,
    metadata: data as DocMetadata,
    content: contentHtml,
  };
}

async function generateDocs() {
  const docs: Doc[] = [];
  const guides: Doc[] = [];

  // Process docs
  if (fs.existsSync(docsDirectory)) {
    const docFiles = fs.readdirSync(docsDirectory).filter(f => f.endsWith('.md'));
    for (const file of docFiles) {
      const slug = file.replace(/\.md$/, '');
      const doc = await processDoc(path.join(docsDirectory, file), slug);
      docs.push(doc);
    }
  }

  // Process guides
  if (fs.existsSync(guidesDirectory)) {
    const guideFiles = fs.readdirSync(guidesDirectory).filter(f => f.endsWith('.md'));
    for (const file of guideFiles) {
      const slug = file.replace(/\.md$/, '');
      const guide = await processDoc(path.join(guidesDirectory, file), slug);
      guides.push(guide);
    }
  }

  // Sort
  docs.sort((a, b) => {
    if (a.metadata.order !== undefined && b.metadata.order !== undefined) {
      return a.metadata.order - b.metadata.order;
    }
    return a.slug.localeCompare(b.slug);
  });

  guides.sort((a, b) => {
    if (a.metadata.order !== undefined && b.metadata.order !== undefined) {
      return a.metadata.order - b.metadata.order;
    }
    return a.slug.localeCompare(b.slug);
  });

  // Write to JSON
  const outputPath = path.join(process.cwd(), 'src', 'generated');
  if (!fs.existsSync(outputPath)) {
    fs.mkdirSync(outputPath, { recursive: true });
  }

  const jsonContent = JSON.stringify({ docs, guides }, null, 2);
  
  fs.writeFileSync(
    path.join(outputPath, 'docs.json'),
    jsonContent
  );
  
  // Also copy to public for runtime access
  const publicPath = path.join(process.cwd(), 'public');
  fs.writeFileSync(
    path.join(publicPath, 'docs.json'),
    jsonContent
  );

  console.log(`Generated ${docs.length} docs and ${guides.length} guides`);
}

generateDocs().catch(console.error);
