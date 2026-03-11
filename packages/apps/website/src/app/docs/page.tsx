import { Link } from "react-router-dom";
import { getAllDocs } from "@/lib/markdown";

export default function DocsPage() {
  const docs = getAllDocs();

  return (
    <div className="max-w-7xl mx-auto px-4 py-12">
      <div className="mb-12 text-center">
        <h1 className="text-5xl font-bold mb-4 text-[#C50022]">
          Documentation
        </h1>
        <div className="w-16 h-1 mx-auto mb-6 bg-[#C50022]"></div>
        <p className="text-lg text-[#9CA3AF] max-w-2xl mx-auto">
          Learn about press architecture, features, and how to integrate your AI agents.
        </p>
      </div>

      <div className="grid gap-6">
        {docs.map((doc) => (
          <Link 
            key={doc.slug} 
            to={`/docs/${doc.slug}`}
            className="block bg-[#1F1F24] border border-[#3A3A4A] rounded-xl p-8 hover:border-[#C50022]/60 transition-all group"
          >
            <h3 className="text-2xl font-bold mb-3 text-[#F4F6FC] group-hover:text-[#C50022] transition-colors">
              {doc.metadata.title || doc.slug}
            </h3>
            {doc.metadata.description && (
              <p className="text-base leading-relaxed text-[#9CA3AF]">
                {doc.metadata.description}
              </p>
            )}
          </Link>
        ))}
      </div>
    </div>
  );
}
