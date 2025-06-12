---
layout: ../components/Layout.astro
title: Tilia - Simple State Management for TypeScript & ReScript
description: Lightning-fast, zero-dependency state management library for TypeScript and ReScript. Minimalist API with type safety and FRP helpers for modern web applications.
keywords: state management, TypeScript, ReScript, React, JavaScript, reactive programming, FRP, proxy tracking, zero dependencies, performance, pull reactivity, push reactivity
---

<section class="intro wide-comment">
  <div class="space-y-6">
    <h1
      class="text-3xl xl:text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-yellow-200 to-cyan-100 mt-16">
      Simple State Management
    </h1>
    <p class="text-xl font-medium text-white/80">
      A state management library for TypeScript and ReScript supporting best practices.
    </p>
    <p class="rainbow">We believe code should be readable. Tilia is here to help you achieve that. ✨✨</p>
    <div class="flex flex-row space-x-4 justify-center gap-4 mt-16">
      <a href="/docs"
        class="bg-gradient-to-r from-green-400 to-blue-500 px-6 py-3 rounded-full font-bold hover:scale-105 transform transition">
        Get Started
      </a>
      <a href="https://github.com/tiliajs/tilia"
        class="border-2 border-white/50 px-6 py-3 rounded-full font-bold hover:bg-white/20 transition">
        GitHub
      </a>
    </div>
  </div>
  <div>

```typescript
const sky = tilia({
  color: 'pink' 🌈
})

observe(() => {
  console.log(sky.color)
})

function elevateVibes() {
  sky.color = 'legendary' ✨
}

// React integration

function Sky() {
  useTilia()

  return <div>{sky.color}</div>
}
```

```rescript
let vibing = tilia({
  vibes: "immaculate" 🌈
})

@react.component
let make = () => {
  useTilia()

  <div>{React.string(vibing.vibes)}</div>
}

let elevateVibes = () => vibing.vibes = "legendary" ✨

```

  </div>
</section>

<section class="bg-black/10 py-16">
  <div class="container mx-auto px-6 text-center">
    <h3 class="text-2xl md:text-3xl font-bold mb-8 text-transparent bg-clip-text bg-gradient-to-r from-blue-300 to-amber-200">
      Why Developers Are Obsessed <small class="text-cyan-200 opacity-40">(or not)</small>
    </h3>
    <div class="grid md:grid-cols-3 gap-8">
      <div class="bg-black/20 p-6 rounded-xl hover:scale-105 transition transform">
        <h4 class="text-xl font-bold mb-4">🌱<br/>No Boilerplate</h4>
        <p class="text-sm">The API has three functions and was made to be nearly invisible in your code.</p>
      </div>
      <div class="bg-black/20 p-6 rounded-xl hover:scale-105 transition transform">
        <h4 class="text-xl font-bold mb-4">🚀<br/> Lightning Fast</h4>
        <p class="text-sm">A library written for data-intensive and highly interactive apps.</p>
      </div>
      <div class="bg-black/20 p-6 rounded-xl hover:scale-105 transition transform">
        <h4 class="text-xl font-bold mb-4">🌈<br/> Type Safe</h4>
        <p class="text-sm">Built with ReScript following best practices, Tilia supports your project from seed to unicorn.</p>
      </div>
      <div class="bg-black/20 backdrop-blur-lg rounded-xl md:p-8 p-4 border border-white/20 md:col-span-3">
        <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-blue-500">
          Main Features
        </h2>
        <div class="grid lg:grid-cols-2 lg:gap-6 gap-3">
          <div class="space-y-3">
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span class="font-bold text-green-300">Zero dependencies</span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Optimized for stability and speed</span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Highly granular reactivity</span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Combines <strong>pull</strong> and <strong>push</strong> reactivity</span>
            </div>
          </div>
          <div class="space-y-3">
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Tracking follows moved or copied objects</span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Compatible with ReScript and TypeScript</span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Optimized computations (no recalculation)</span>
            </div>
            <div class="flex items-center space-x-2">
              <span class="text-green-400">✓</span>
              <span>Tiny footprint (8KB) ✨</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="flex justify-center items-center w-full">
      <div class="flex flex-row gap-4 w-full m-8 max-w-96 justify-evenly">
        <a href="/docs"
          class="bg-gradient-to-r from-green-400/90 to-blue-500/80 px-6 py-3 rounded-full font-bold hover:scale-105 transform transition">
          Get Started
        </a>
        <a href="https://github.com/tiliajs/tilia"
          class="border-2 border-white/50 px-6 py-3 rounded-full font-bold hover:bg-white/20 transition">
          GitHub
        </a>
      </div>
    </div>

  </div>

</section>

</div>
