import { useParams, Link, Navigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { getDocBySlug, getAllDocs } from "@/lib/markdown";
import { ChevronLeft, ChevronRight, List } from "lucide-react";

export default function DocPage() {
  const { slug } = useParams<{ slug: string }>();
  const doc = getDocBySlug(slug!);

  if (!doc) {
    return <Navigate to="/docs" replace />;
  }

  // Get all docs to find next/previous
  const allDocs = getAllDocs('docs');
  const currentIndex = allDocs.findIndex(d => d.slug === slug);
  const prevDoc = currentIndex > 0 ? allDocs[currentIndex - 1] : null;
  const nextDoc = currentIndex < allDocs.length - 1 ? allDocs[currentIndex + 1] : null;

  return (
    <div className="min-h-screen bg-background">
      <div className="max-w-7xl mx-auto px-4 py-12">
        <div className="max-w-5xl mx-auto">
          <Link to="/docs">
            <Button variant="ghost" size="lg" className="mb-10 -ml-4 text-base">
              <ChevronLeft className="mr-2 h-5 w-5" />
              Back to Documentation
            </Button>
          </Link>

          <article className="prose prose-invert prose-lg max-w-none">
            {doc.metadata.description && (
              <p className="text-xl text-muted-foreground mb-8">
                {doc.metadata.description}
              </p>
            )}
            <div className="markdown-content" dangerouslySetInnerHTML={{ __html: doc.content }} />
          </article>

          {/* Navigation Buttons */}
          <div className="mt-16 pt-8 border-t border-border">
            <div className="flex flex-wrap gap-4 items-center justify-between">
              <div className="flex gap-4">
                {prevDoc && (
                  <Link to={`/docs/${prevDoc.slug}`}>
                    <Button variant="outline" size="lg" className="text-base">
                      <ChevronLeft className="mr-2 h-5 w-5" />
                      {prevDoc.metadata.title || prevDoc.slug}
                    </Button>
                  </Link>
                )}
              </div>
              
              <div className="flex gap-4">
                <Link to="/docs">
                  <Button variant="outline" size="lg" className="text-base">
                    <List className="mr-2 h-5 w-5" />
                    All Docs
                  </Button>
                </Link>
                
                {nextDoc && (
                  <Link to={`/docs/${nextDoc.slug}`}>
                    <Button variant="default" size="lg" className="text-base">
                      {nextDoc.metadata.title || nextDoc.slug}
                      <ChevronRight className="ml-2 h-5 w-5" />
                    </Button>
                  </Link>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
