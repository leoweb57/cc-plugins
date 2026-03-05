---
name: nextjs-app-router-patterns
description: >
  S'active quand on travaille avec Next.js 14+ et l'App Router : Server Components, streaming, routes parallèles,
  routes interceptées, Server Actions, stratégies de cache et data fetching avancé. Se déclenche aussi lors d'une
  migration du Pages Router vers l'App Router ou quand on optimise le rendu côté serveur.
---

# Patterns Next.js App Router

Patterns de référence pour l'architecture Next.js 14+ avec App Router, Server Components et développement React full-stack moderne.

## Quand utiliser ce skill

- Construction d'applications Next.js avec l'App Router
- Migration du Pages Router vers l'App Router
- Implémentation de Server Components et streaming
- Mise en place de routes parallèles et interceptées
- Optimisation du data fetching et du cache
- Construction de features full-stack avec les Server Actions

## Concepts fondamentaux

### 1. Modes de rendu

| Mode | Où | Quand l'utiliser |
|------|-----|-----------------|
| **Server Components** | Serveur uniquement | Data fetching, calculs lourds, secrets |
| **Client Components** | Navigateur | Interactivité, hooks, APIs navigateur |
| **Static** | Build time | Contenu qui change rarement |
| **Dynamic** | Request time | Données personnalisées ou temps réel |
| **Streaming** | Progressif | Pages lourdes, sources de données lentes |

### 2. Conventions de fichiers

```
app/
├── layout.tsx       # Wrapper UI partagé
├── page.tsx         # UI de la route
├── loading.tsx      # UI de chargement (Suspense)
├── error.tsx        # Error boundary
├── not-found.tsx    # UI 404
├── route.ts         # Endpoint API
├── template.tsx     # Layout re-monté
├── default.tsx      # Fallback route parallèle
└── opengraph-image.tsx  # Génération d'image OG
```

## Démarrage rapide

```typescript
// app/layout.tsx
import { Inter } from 'next/font/google'
import { Providers } from './providers'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: { default: 'My App', template: '%s | My App' },
  description: 'Built with Next.js App Router',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}

// app/page.tsx — Server Component par défaut
async function getProducts() {
  const res = await fetch('https://api.example.com/products', {
    next: { revalidate: 3600 }, // ISR : revalidation toutes les heures
  })
  return res.json()
}

export default async function HomePage() {
  const products = await getProducts()

  return (
    <main>
      <h1>Products</h1>
      <ProductGrid products={products} />
    </main>
  )
}
```

## Patterns

### Pattern 1 : Server Components avec data fetching

```typescript
// app/products/page.tsx
import { Suspense } from 'react'
import { ProductList, ProductListSkeleton } from '@/components/products'
import { FilterSidebar } from '@/components/filters'

interface SearchParams {
  category?: string
  sort?: 'price' | 'name' | 'date'
  page?: string
}

export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>
}) {
  const params = await searchParams

  return (
    <div className="flex gap-8">
      <FilterSidebar />
      <Suspense
        key={JSON.stringify(params)}
        fallback={<ProductListSkeleton />}
      >
        <ProductList
          category={params.category}
          sort={params.sort}
          page={Number(params.page) || 1}
        />
      </Suspense>
    </div>
  )
}

// components/products/ProductList.tsx — Server Component
async function getProducts(filters: ProductFilters) {
  const res = await fetch(
    `${process.env.API_URL}/products?${new URLSearchParams(filters)}`,
    { next: { tags: ['products'] } }
  )
  if (!res.ok) throw new Error('Failed to fetch products')
  return res.json()
}

export async function ProductList({ category, sort, page }: ProductFilters) {
  const { products, totalPages } = await getProducts({ category, sort, page })

  return (
    <div>
      <div className="grid grid-cols-3 gap-4">
        {products.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
      <Pagination currentPage={page} totalPages={totalPages} />
    </div>
  )
}
```

### Pattern 2 : Client Components avec 'use client'

```typescript
// components/products/AddToCartButton.tsx
'use client'

import { useState, useTransition } from 'react'
import { addToCart } from '@/app/actions/cart'

export function AddToCartButton({ productId }: { productId: string }) {
  const [isPending, startTransition] = useTransition()
  const [error, setError] = useState<string | null>(null)

  const handleClick = () => {
    setError(null)
    startTransition(async () => {
      const result = await addToCart(productId)
      if (result.error) {
        setError(result.error)
      }
    })
  }

  return (
    <div>
      <button
        onClick={handleClick}
        disabled={isPending}
        className="btn-primary"
      >
        {isPending ? 'Ajout...' : 'Ajouter au panier'}
      </button>
      {error && <p className="text-red-500 text-sm">{error}</p>}
    </div>
  )
}
```

### Pattern 3 : Server Actions

```typescript
// app/actions/cart.ts
'use server'

import { revalidateTag } from 'next/cache'
import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'

export async function addToCart(productId: string) {
  const cookieStore = await cookies()
  const sessionId = cookieStore.get('session')?.value

  if (!sessionId) {
    redirect('/login')
  }

  try {
    await db.cart.upsert({
      where: { sessionId_productId: { sessionId, productId } },
      update: { quantity: { increment: 1 } },
      create: { sessionId, productId, quantity: 1 },
    })

    revalidateTag('cart')
    return { success: true }
  } catch (error) {
    return { error: 'Impossible d\'ajouter au panier' }
  }
}

export async function checkout(formData: FormData) {
  const address = formData.get('address') as string
  const payment = formData.get('payment') as string

  // Validation
  if (!address || !payment) {
    return { error: 'Champs obligatoires manquants' }
  }

  // Traitement de la commande
  const order = await processOrder({ address, payment })

  // Redirection vers la confirmation
  redirect(`/orders/${order.id}/confirmation`)
}
```

### Pattern 4 : Routes parallèles

```typescript
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  analytics,
  team,
}: {
  children: React.ReactNode
  analytics: React.ReactNode
  team: React.ReactNode
}) {
  return (
    <div className="dashboard-grid">
      <main>{children}</main>
      <aside className="analytics-panel">{analytics}</aside>
      <aside className="team-panel">{team}</aside>
    </div>
  )
}

// app/dashboard/@analytics/page.tsx
export default async function AnalyticsSlot() {
  const stats = await getAnalytics()
  return <AnalyticsChart data={stats} />
}

// app/dashboard/@analytics/loading.tsx
export default function AnalyticsLoading() {
  return <ChartSkeleton />
}

// app/dashboard/@team/page.tsx
export default async function TeamSlot() {
  const members = await getTeamMembers()
  return <TeamList members={members} />
}
```

### Pattern 5 : Routes interceptées (pattern modal)

```typescript
// Structure de fichiers pour une modale photo
// app/
// ├── @modal/
// │   ├── (.)photos/[id]/page.tsx  # Interception
// │   └── default.tsx
// ├── photos/
// │   └── [id]/page.tsx            # Page complète
// └── layout.tsx

// app/@modal/(.)photos/[id]/page.tsx
import { Modal } from '@/components/Modal'
import { PhotoDetail } from '@/components/PhotoDetail'

export default async function PhotoModal({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const photo = await getPhoto(id)

  return (
    <Modal>
      <PhotoDetail photo={photo} />
    </Modal>
  )
}

// app/photos/[id]/page.tsx — version page complète
export default async function PhotoPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const photo = await getPhoto(id)

  return (
    <div className="photo-page">
      <PhotoDetail photo={photo} />
      <RelatedPhotos photoId={id} />
    </div>
  )
}

// app/layout.tsx
export default function RootLayout({
  children,
  modal,
}: {
  children: React.ReactNode
  modal: React.ReactNode
}) {
  return (
    <html>
      <body>
        {children}
        {modal}
      </body>
    </html>
  )
}
```

### Pattern 6 : Streaming avec Suspense

```typescript
// app/product/[id]/page.tsx
import { Suspense } from 'react'

export default async function ProductPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params

  // Ces données chargent en premier (bloquant)
  const product = await getProduct(id)

  return (
    <div>
      {/* Rendu immédiat */}
      <ProductHeader product={product} />

      {/* Stream progressif des avis */}
      <Suspense fallback={<ReviewsSkeleton />}>
        <Reviews productId={id} />
      </Suspense>

      {/* Stream progressif des recommandations */}
      <Suspense fallback={<RecommendationsSkeleton />}>
        <Recommendations productId={id} />
      </Suspense>
    </div>
  )
}

// Ces composants fetchent leurs propres données
async function Reviews({ productId }: { productId: string }) {
  const reviews = await getReviews(productId) // API lente
  return <ReviewList reviews={reviews} />
}

async function Recommendations({ productId }: { productId: string }) {
  const products = await getRecommendations(productId) // ML, lent
  return <ProductCarousel products={products} />
}
```

### Pattern 7 : Route Handlers (API Routes)

```typescript
// app/api/products/route.ts
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams
  const category = searchParams.get('category')

  const products = await db.product.findMany({
    where: category ? { category } : undefined,
    take: 20,
  })

  return NextResponse.json(products)
}

export async function POST(request: NextRequest) {
  const body = await request.json()

  const product = await db.product.create({
    data: body,
  })

  return NextResponse.json(product, { status: 201 })
}

// app/api/products/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const product = await db.product.findUnique({ where: { id } })

  if (!product) {
    return NextResponse.json(
      { error: 'Produit non trouvé' },
      { status: 404 }
    )
  }

  return NextResponse.json(product)
}
```

### Pattern 8 : Metadata et SEO

```typescript
// app/products/[slug]/page.tsx
import { Metadata } from 'next'
import { notFound } from 'next/navigation'

type Props = {
  params: Promise<{ slug: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const product = await getProduct(slug)

  if (!product) return {}

  return {
    title: product.name,
    description: product.description,
    openGraph: {
      title: product.name,
      description: product.description,
      images: [{ url: product.image, width: 1200, height: 630 }],
    },
    twitter: {
      card: 'summary_large_image',
      title: product.name,
      description: product.description,
      images: [product.image],
    },
  }
}

export async function generateStaticParams() {
  const products = await db.product.findMany({ select: { slug: true } })
  return products.map((p) => ({ slug: p.slug }))
}

export default async function ProductPage({ params }: Props) {
  const { slug } = await params
  const product = await getProduct(slug)

  if (!product) notFound()

  return <ProductDetail product={product} />
}
```

## Stratégies de cache

### Data Cache

```typescript
// Pas de cache (toujours frais)
fetch(url, { cache: 'no-store' })

// Cache permanent (statique)
fetch(url, { cache: 'force-cache' })

// ISR — revalidation après 60 secondes
fetch(url, { next: { revalidate: 60 } })

// Invalidation par tags
fetch(url, { next: { tags: ['products'] } })

// Invalidation via Server Action
'use server'
import { revalidateTag, revalidatePath } from 'next/cache'

export async function updateProduct(id: string, data: ProductData) {
  await db.product.update({ where: { id }, data })
  revalidateTag('products')
  revalidatePath('/products')
}
```

## Bonnes pratiques

### A faire
- **Commencer par les Server Components** — Ajouter `'use client'` seulement quand c'est nécessaire
- **Colocaliser le data fetching** — Fetcher les données là où elles sont utilisées
- **Utiliser des Suspense boundaries** — Activer le streaming pour les données lentes
- **Exploiter les routes parallèles** — États de chargement indépendants
- **Utiliser les Server Actions** — Pour les mutations avec progressive enhancement

### A éviter
- **Ne pas passer de données non sérialisables** — Limitation de la frontière Server → Client
- **Ne pas utiliser de hooks dans les Server Components** — Pas de useState, useEffect
- **Ne pas fetcher dans les Client Components** — Utiliser les Server Components ou React Query
- **Ne pas sur-imbriquer les layouts** — Chaque layout alourdit l'arbre de composants
- **Ne pas ignorer les états de chargement** — Toujours fournir loading.tsx ou Suspense

## Ressources

- [Documentation Next.js App Router](https://nextjs.org/docs/app)
- [RFC Server Components](https://github.com/reactjs/rfcs/blob/main/text/0188-server-components.md)
- [Templates Vercel](https://vercel.com/templates/next.js)
