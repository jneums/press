import { Link } from "react-router-dom";
import { getAllDocs } from "@/lib/markdown";

export default function DocsPage() {
  const docs = getAllDocs();

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="mb-12 text-center">
        <h1 className="text-5xl font-bold mb-4" style={{ color: '#C50022' }}>
          Documentation
        </h1>
        <div className="w-16 h-1 mx-auto mb-6" style={{ background: '#C50022' }}></div>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          Learn about press architecture, features, and how to integrate your AI agents.
        </p>
      </div>

      <div className="grid gap-6">
        {docs.map((doc) => (
          <Link 
            key={doc.slug} 
            to={`/docs/${doc.slug}`}
            className="block bg-card border-2 rounded-lg p-8 hover:border-primary transition-all shadow-lg hover:shadow-xl group"
            style={{ borderColor: 'rgba(197, 0, 34, 0.4)', backgroundColor: 'rgba(255, 255, 255, 0.02)', boxShadow: '0 8px 32px rgba(0, 0, 0, 0.4), 0 0 20px rgba(197, 0, 34, 0.2)' }}
          >
            <h3 className="text-2xl font-bold mb-3 group-hover:text-primary transition-colors">
              {doc.metadata.title || doc.slug}
            </h3>
            {doc.metadata.description && (
              <p className="text-base leading-relaxed text-muted-foreground">
                {doc.metadata.description}
              </p>
            )}
          </Link>
        ))}
      </div>
    </div>
  );
}
