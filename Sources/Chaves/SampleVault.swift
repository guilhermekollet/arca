import Foundation

/// The made-up vault `Chaves --sample` opens, for screenshots and UI work. Every value is fake.
enum SampleVault {
    static var projects: [Project] {
        let now = Date()
        return [
            Project(
                name: "Loja Aurora",
                symbol: "cart",
                status: .active,
                summary: "E-commerce em Next.js com Supabase e pagamentos por Pix.",
                tags: ["next.js", "supabase", "vercel"],
                context: """
                ## Como rodar
                npm install
                npm run dev  # http://localhost:3000

                ## Deploy
                Push na main publica na Vercel. As migrations rodam com `supabase db push`.

                ## Onde está o quê
                - Pagamentos: app/api/checkout
                - E-mails transacionais: emails/

                ## Decisões
                - O carrinho fica no banco, não no navegador, para recuperar carrinhos abandonados.

                ## Contatos
                - Design: Ana (Figma da loja)
                """,
                localPath: "~/Code/loja-aurora",
                links: [
                    ProjectLink(title: "Repositório", url: "https://github.com/example/loja-aurora"),
                    ProjectLink(title: "Produção", url: "https://aurora.example.com"),
                    ProjectLink(title: "Supabase", url: "https://supabase.com/dashboard/project/example"),
                ],
                environments: [
                    EnvironmentSet(name: "development", variables: [
                        Variable(key: "NEXT_PUBLIC_SUPABASE_URL", value: "http://127.0.0.1:54321"),
                        Variable(key: "SUPABASE_SERVICE_ROLE_KEY", value: "sample-service-role-key", isSecret: true),
                        Variable(key: "PIX_WEBHOOK_SECRET", value: "sample-webhook-secret", isSecret: true),
                    ]),
                    EnvironmentSet(name: "production", variables: [
                        Variable(key: "NEXT_PUBLIC_SUPABASE_URL", value: "https://example.supabase.co"),
                        Variable(key: "SUPABASE_SERVICE_ROLE_KEY", value: "sample-production-key", isSecret: true),
                        Variable(key: "PIX_WEBHOOK_SECRET", value: "sample-production-secret", isSecret: true),
                    ]),
                ],
                credentials: [
                    Credential(kind: .website, title: "Vercel", url: "https://vercel.com/login", username: "dev@example.com", password: "sample-password-1"),
                    Credential(kind: .database, title: "Postgres de produção", url: "postgres://db.example.supabase.co:5432/postgres", username: "postgres", password: "sample-password-2"),
                ],
                updatedAt: now
            ),
            Project(
                name: "API de Cobranças",
                symbol: "creditcard",
                status: .maintenance,
                summary: "NestJS que emite boletos e assinaturas; só correções.",
                tags: ["nestjs", "postgres", "docker"],
                context: """
                ## Como rodar
                docker compose up -d
                npm run start:dev

                ## Armadilhas
                - O webhook do gateway reenvia eventos: toda escrita precisa ser idempotente.
                """,
                localPath: "~/Code/api-cobrancas",
                links: [ProjectLink(title: "Repositório", url: "https://github.com/example/api-cobrancas")],
                environments: [
                    EnvironmentSet(name: "development", variables: [
                        Variable(key: "DATABASE_URL", value: "postgres://postgres:postgres@localhost:5432/cobrancas", isSecret: true),
                        Variable(key: "GATEWAY_API_KEY", value: "sample-sandbox-key", isSecret: true),
                    ]),
                    EnvironmentSet(name: "staging", variables: [
                        Variable(key: "GATEWAY_API_KEY", value: "sample-staging-key", isSecret: true),
                    ]),
                ],
                credentials: [
                    Credential(kind: .server, title: "VPS de staging", url: "ssh://deploy@203.0.113.10", username: "deploy", password: "sample-password-3"),
                    Credential(kind: .apiKey, title: "Gateway (sandbox)", url: "https://sandbox.example.com", password: "sample-api-key"),
                ],
                updatedAt: now.addingTimeInterval(-86_400 * 3)
            ),
            Project(
                name: "Site institucional",
                symbol: "globe",
                status: .paused,
                summary: "Astro, publicado no GitHub Pages.",
                tags: ["astro"],
                updatedAt: now.addingTimeInterval(-86_400 * 40)
            ),
            Project(
                name: "App do Clube",
                symbol: "iphone",
                status: .archived,
                summary: "App em React Native, desligado em 2025.",
                updatedAt: now.addingTimeInterval(-86_400 * 300)
            ),
        ]
    }
}
