---
layout: ../components/Layout.astro
title: Documentation Tilia - Guide Complet en Français
description: Guide complet pour comprendre et utiliser Tilia, une bibliothèque de gestion d'état simple et performante. Documentation en français avec exemples pratiques.
keywords: tilia documentation, guide français, gestion d'état, programmation réactive, FRP, domain-driven design, React, TypeScript, ReScript
---

<main class="container mx-auto px-6 py-8 max-w-4xl">
<section class="header">

# Documentation Tilia {.documentation}

Guide complet pour comprendre et utiliser Tilia, une bibliothèque de gestion d'état simple et performante. {.subtitle}

<div class="text-center mt-4">
  <a href="/guide" class="text-white/70 hover:text-white/90 underline text-sm">📖 Read in English</a>
</div>

</section>

<a id="installation"></a>

<section class="doc installation">

## Installation

```bash
# Version stable
npm install tilia

# Avec React
npm install tilia @tilia/react
```

</section>

<a id="goals"></a>

<section class="doc goals">

## Objectifs et Non-objectifs

<strong class="goal-text">L'objectif</strong> de Tilia est de fournir une solution de gestion d'état minimale et rapide qui supporte le développement orienté domaine (comme l'Architecture Clean ou Diagonal). Tilia est conçu pour que votre code ressemble et se comporte comme de la logique métier, plutôt que d'être encombré par des détails spécifiques à la bibliothèque.

<strong class="non-goal-text">Non-objectif</strong> Tilia n'est pas un framework.

</section>

## Concepts Fondamentaux {.api}

<a id="frp"></a>

<section class="doc frp wide-comment">

### Qu'est-ce que la Programmation Réactive Fonctionnelle (FRP) ?

La **Programmation Réactive Fonctionnelle** (Functional Reactive Programming, FRP) est un paradigme de programmation qui combine deux approches puissantes :

1. **La programmation fonctionnelle** : manipulation de données via des fonctions pures, sans effets de bord
2. **La programmation réactive** : propagation automatique des changements à travers le système

#### Le problème que résout la FRP

Dans une application traditionnelle, quand une donnée change, il faut manuellement mettre à jour toutes les parties de l'application qui en dépendent. Cela mène à du code complexe, fragile et difficile à maintenir :

```typescript
// ❌ Approche impérative traditionnelle
let count = 0;
let double = count * 2;
let quadruple = double * 2;

count = 5;
// Oups ! double et quadruple sont maintenant obsolètes
// Il faut les recalculer manuellement...
double = count * 2;
quadruple = double * 2;
```

Avec la FRP, les dépendances sont déclarées une seule fois et les mises à jour se propagent automatiquement :

```typescript
// ✅ Approche réactive avec Tilia
import { tilia, computed, observe } from "tilia";

const state = tilia({
  count: 0,
  double: computed(() => state.count * 2),
  quadruple: computed(() => state.double * 2),
});

observe(() => {
  console.log(`count=${state.count}, double=${state.double}, quadruple=${state.quadruple}`);
});

state.count = 5;
// ✨ Automatiquement : double=10, quadruple=20
// Le callback observe() est appelé avec les nouvelles valeurs
```

#### Les deux modèles de réactivité

Tilia combine intelligemment deux modèles de réactivité complémentaires :

**Réactivité PUSH (observe, watch)**

Le modèle **push** signifie que les changements "poussent" des notifications vers les observateurs. Quand une valeur change, tous les callbacks qui en dépendent sont automatiquement ré-exécutés.

```typescript
observe(() => {
  // Ce callback sera appelé chaque fois que alice.age change
  console.log("Alice a", alice.age, "ans");
});

alice.age = 11; // ✨ Déclenche automatiquement le callback
```

**Cas d'usage** : Effets de bord (logs, mises à jour DOM, appels API), synchronisation d'état.

**Réactivité PULL (computed)**

Le modèle **pull** signifie que les valeurs sont calculées paresseusement (lazily), uniquement quand elles sont lues. La valeur est ensuite mise en cache jusqu'à ce qu'une de ses dépendances change.

```typescript
const state = tilia({
  items: [1, 2, 3, 4, 5],
  // Calculé seulement quand 'total' est lu
  total: computed(() => state.items.reduce((a, b) => a + b, 0)),
});

// Première lecture : calcul effectué, résultat mis en cache
console.log(state.total); // 15

// Deuxième lecture : valeur retournée depuis le cache (pas de recalcul)
console.log(state.total); // 15

state.items.push(6); // Invalide le cache

// Lecture après modification : recalcul
console.log(state.total); // 21
```

**Cas d'usage** : Valeurs dérivées, transformations de données, filtres, agrégations.

#### Pourquoi combiner les deux ?

| Modèle   | Avantage                           | Inconvénient                                                |
| -------- | ---------------------------------- | ----------------------------------------------------------- |
| **Push** | Réaction immédiate aux changements | Peut recalculer inutilement si la valeur n'est pas utilisée |
| **Pull** | Calcul uniquement si nécessaire    | Nécessite une lecture pour déclencher le calcul             |

Tilia vous permet de choisir le modèle approprié selon le contexte, optimisant ainsi les performances tout en gardant un code expressif.

</section>

<a id="observer-pattern"></a>

<section class="doc observe wide-comment">

### Le Pattern Observer

#### Le pattern classique

Le **pattern Observer** (ou Publish-Subscribe) est un design pattern comportemental où un objet, appelé **Subject** (sujet), maintient une liste d'**Observers** (observateurs) et les notifie automatiquement de tout changement d'état.

```
┌─────────────────┐           ┌─────────────────┐
│     Subject     │──notifie──▶│    Observer 1   │
│  (source de     │           ├─────────────────┤
│   vérité)       │──notifie──▶│    Observer 2   │
│                 │           ├─────────────────┤
│                 │──notifie──▶│    Observer 3   │
└─────────────────┘           └─────────────────┘
```

Dans l'implémentation classique, l'observateur doit explicitement s'abonner et se désabonner :

```typescript
// Pattern Observer classique
subject.subscribe(observer);    // Abonnement manuel
// ... plus tard
subject.unsubscribe(observer);  // Désabonnement manuel (source de bugs !)
```

#### L'approche Tilia : tracking automatique

Tilia révolutionne ce pattern en **détectant automatiquement** quelles propriétés sont observées. Pas besoin de s'abonner ou se désabonner manuellement !

```typescript
import { tilia, observe } from "tilia";

const alice = tilia({
  name: "Alice",
  age: 10,
  city: "Paris",
});

observe(() => {
  // Tilia détecte que seuls 'name' et 'age' sont lus
  console.log(`${alice.name} a ${alice.age} ans`);
});

alice.age = 11;     // ✨ Déclenche le callback (age est observé)
alice.city = "Lyon"; // 😴 Ne déclenche PAS le callback (city n'est pas observé)
```

#### Tracking dynamique : seule la dernière exécution compte

Un point crucial à comprendre : Tilia ne regarde pas statiquement quelles propriétés **pourraient** être lues dans votre fonction. Il enregistre uniquement les propriétés qui ont été **effectivement lues lors de la dernière exécution** du callback.

Cela signifie que si votre callback contient une condition `if`, les dépendances changent selon la branche exécutée :

```typescript
import { tilia, observe } from "tilia";

const state = tilia({
  showDetails: false,
  name: "Alice",
  email: "alice@example.com",
  phone: "01 23 45 67 89",
});

observe(() => {
  // 'name' est TOUJOURS lu
  console.log("Nom:", state.name);
  
  if (state.showDetails) {
    // 'email' et 'phone' ne sont lus QUE si showDetails === true
    console.log("Email:", state.email);
    console.log("Téléphone:", state.phone);
  }
});

// État initial : showDetails = false
// Dépendances actuelles : { name, showDetails }

state.email = "new@email.com";
// 😴 Pas de notification ! 'email' n'a pas été lu lors de la dernière exécution

state.showDetails = true;
// ✨ Notification ! showDetails est observé
// Le callback se ré-exécute, cette fois en lisant email et phone
// Nouvelles dépendances : { name, showDetails, email, phone }

state.email = "another@email.com";
// ✨ Notification ! Maintenant email EST observé
```

Ce comportement dynamique est extrêmement puissant : vos callbacks ne sont jamais notifiés pour des valeurs qu'ils n'utilisent pas réellement, ce qui optimise automatiquement les performances.

</section>

<a id="dependency-graph"></a>

<section class="doc computed wide-comment">

### Comment Tilia Construit le Graphe de Dépendances

#### L'API Proxy de JavaScript

Tilia utilise l'[API Proxy](https://developer.mozilla.org/fr/docs/Web/JavaScript/Reference/Global_Objects/Proxy) de JavaScript pour intercepter les accès aux propriétés des objets. Un Proxy est un wrapper transparent qui permet de définir des comportements personnalisés pour les opérations fondamentales (lecture, écriture, etc.).

```typescript
// Principe simplifié du Proxy
const handler = {
  get(target, property) {
    console.log(`Lecture de ${property}`);
    return target[property];
  },
  set(target, property, value) {
    console.log(`Écriture de ${property} = ${value}`);
    target[property] = value;
    return true;
  }
};

const obj = { name: "Alice" };
const proxy = new Proxy(obj, handler);

proxy.name;        // Log: "Lecture de name"
proxy.name = "Bob"; // Log: "Écriture de name = Bob"
```

#### Le mécanisme de tracking

Quand vous appelez `tilia({...})`, l'objet est enveloppé dans un Proxy avec deux "traps" (interceptions) essentielles :

**1. Le trap GET (lecture)**

Quand une propriété est lue **pendant l'exécution d'un callback d'observation**, Tilia enregistre cette propriété comme dépendance :

```typescript
// État interne simplifié de Tilia
let currentObserver = null;  // L'observateur en cours d'exécution
const dependencies = new Map();  // Map: observer -> Set de dépendances

const handler = {
  get(target, key) {
    if (currentObserver !== null) {
      // 📝 Enregistrement de la dépendance
      // "Cet observateur dépend de cette propriété"
      addDependency(currentObserver, target, key);
    }
    return target[key];
  },
  // ...
};
```

**2. Le trap SET (écriture)**

Quand une propriété est modifiée, Tilia trouve tous les observateurs qui en dépendent et les notifie :

```typescript
const handler = {
  // ...
  set(target, key, value) {
    const oldValue = target[key];
    target[key] = value;
    
    if (oldValue !== value) {
      // 📢 Notification des observateurs
      // "Cette propriété a changé, prévenez tous ceux qui en dépendent"
      notifyObservers(target, key);
    }
    return true;
  }
};
```

#### Graphe dynamique

Un point crucial : le graphe de dépendances est **dynamique**. Il est reconstruit à chaque exécution du callback, ce qui permet de gérer des conditions :

```typescript
const state = tilia({
  showDetails: false,
  name: "Alice",
  email: "alice@example.com",
});

observe(() => {
  console.log("Nom:", state.name);
  
  if (state.showDetails) {
    // 'email' n'est observé QUE si showDetails est true
    console.log("Email:", state.email);
  }
});

// Dépendances actuelles: {name, showDetails}

state.email = "new@email.com";  // 😴 Pas de notification (email non observé)

state.showDetails = true;       // ✨ Notification + ré-exécution
// Maintenant les dépendances incluent: {name, showDetails, email}

state.email = "another@email.com"; // ✨ Notification (email est maintenant observé)
```

</section>

<a id="ddd"></a>

<section class="doc ddd wide-comment">

### Carve et le Domain-Driven Design

#### Le problème de la complexité accidentelle

Dans beaucoup de bibliothèques de gestion d'état, le code métier finit par être pollué par des concepts techniques. Les développeurs doivent constamment jongler entre la logique du domaine et les mécanismes réactifs :

```typescript
// ❌ Code pollué par les concepts FRP
const personStore = createStore({
  firstName: signal("Alice"),
  lastName: signal("Dupont"),
  fullName: computed(() => 
    personStore.firstName.get() + " " + personStore.lastName.get()
  ),
});

// Pour lire une valeur, il faut "penser FRP"
const nom = personStore.firstName.get();  // .get() ? .value ? ()  ?
personStore.lastName.set("Martin");        // .set() ? .update() ?
```

Ce code expose la **plomberie réactive** au lieu du **domaine métier**. L'expert métier qui lirait ce code verrait des `.get()`, `.set()`, `signal()` au lieu de voir simplement "une personne avec un nom".

#### L'approche Tilia : le domaine d'abord

Avec Tilia, vous manipulez vos objets métier comme des objets JavaScript ordinaires. La réactivité est **invisible** :

```typescript
// ✅ Code orienté domaine
const personne = tilia({
  prenom: "Alice",
  nom: "Dupont",
  nomComplet: computed(() => `${personne.prenom} ${personne.nom}`),
});

// Lecture naturelle, comme un objet normal
console.log(personne.prenom);     // "Alice"
console.log(personne.nomComplet); // "Alice Dupont"

// Modification naturelle
personne.nom = "Martin";
console.log(personne.nomComplet); // "Alice Martin" ✨ Automatique
```

Ici, `personne.prenom` se lit exactement comme dans n'importe quel code JavaScript. Pas de `.get()`, pas de `.value`, pas de fonction à appeler. C'est simplement un objet avec des propriétés.

#### Le langage ubiquitaire (Ubiquitous Language)

Le **Domain-Driven Design** (DDD) insiste sur l'importance d'un vocabulaire partagé entre développeurs et experts métier. Ce vocabulaire, appelé "langage ubiquitaire", doit se retrouver directement dans le code.

Tilia facilite cette approche en permettant d'écrire du code qui **ressemble au domaine** :

```typescript
// Le code parle le même langage que le métier
const panier = tilia({
  articles: [],
  codePromo: null,
  
  sousTotal: computed(() => 
    panier.articles.reduce((sum, a) => sum + a.prix * a.quantite, 0)
  ),
  
  reduction: computed(() => 
    panier.codePromo?.pourcentage 
      ? panier.sousTotal * panier.codePromo.pourcentage / 100 
      : 0
  ),
  
  total: computed(() => panier.sousTotal - panier.reduction),
});

// Un expert métier peut lire et comprendre ce code
if (panier.total > 100) {
  appliquerFraisDePortGratuits();
}
```

Aucune trace de FRP dans ce code. On parle de `panier`, `articles`, `total` - exactement les mêmes termes qu'utiliserait un responsable e-commerce.

#### Bounded Contexts et modularité

En DDD, un **Bounded Context** est une limite conceptuelle où un modèle particulier est défini et applicable. Tilia et `carve` permettent naturellement de créer ces frontières :

```typescript
// Contexte "Catalogue"
const catalogue = carve<CatalogueContext>(({ derived }) => ({
  produits: [],
  categories: [],
  rechercher: derived((self) => (terme: string) => { /* ... */ }),
  filtrerParCategorie: derived((self) => (cat: string) => { /* ... */ }),
}));

// Contexte "Panier" - modèle différent, même produit
const panier = carve<PanierContext>(({ derived }) => ({
  lignes: [],  // Pas "produits" - vocabulaire différent dans ce contexte
  ajouter: derived((self) => (produit: Produit, quantite: number) => { /* ... */ }),
  total: derived((self) => /* ... */),
}));
```

Chaque contexte utilise son propre vocabulaire, ses propres règles, tout en restant réactif.

</section>

## Guide Pratique {.api}

<a id="premiers-pas"></a>

<section class="doc tilia wide-comment">

### Installation et Premier Pas

#### Créer un objet réactif

La fonction `tilia()` transforme un objet JavaScript ordinaire en un objet réactif :

```typescript
import { tilia } from "tilia";

// Créer un objet réactif
const user = tilia({
  name: "Alice",
  age: 25,
  preferences: {
    theme: "dark",
    language: "fr",
  },
});

// L'utiliser comme un objet normal
console.log(user.name);         // "Alice"
user.age = 26;                  // Modification normale
user.preferences.theme = "light"; // Les objets imbriqués sont aussi réactifs
```

**Points clés :**
- L'objet retourné se comporte exactement comme un objet normal
- Tous les objets imbriqués sont automatiquement rendus réactifs
- Les tableaux sont également supportés

```typescript
const todos = tilia({
  items: [
    { id: 1, text: "Apprendre Tilia", done: false },
    { id: 2, text: "Créer une app", done: false },
  ],
});

// Les opérations sur tableaux sont trackées
todos.items.push({ id: 3, text: "Déployer", done: false });
todos.items[0].done = true;
```

</section>

<a id="observe"></a>

<section class="doc observe wide-comment">

### observe

Utilisez `observe` pour surveiller les changements et réagir automatiquement. Quand une valeur observée change, votre fonction callback est déclenchée (**push** réactivité).

Pendant l'exécution du callback, Tilia suit quelles propriétés sont accédées dans les objets et tableaux connectés. Le callback s'exécute toujours au moins une fois lors de la configuration initiale de `observe`.

```typescript
import { tilia, observe } from "tilia";

const counter = tilia({ value: 0 });

observe(() => {
  console.log("Compteur:", counter.value);
});
// Output immédiat: "Compteur: 0"

counter.value = 1;  // Output: "Compteur: 1"
counter.value = 2;  // Output: "Compteur: 2"
```

**⚠️ Note importante :** Si vous modifiez une valeur observée dans le callback `observe`, celui-ci sera ré-exécuté après sa fin. Cela permet d'implémenter des machines à états.

```typescript
observe(() => {
  console.log("Valeur:", state.value);
  if (state.value < 10) {
    state.value++;  // ⚠️ Provoque une ré-exécution
  }
});
```

</section>

<a id="watch"></a>

<section class="doc watch wide-comment">

### watch

Utilisez `watch` de manière similaire à `observe`, mais avec une séparation claire entre la phase de capture et la phase d'effet. La **fonction de capture** observe les valeurs, et la **fonction d'effet** est appelée quand les valeurs capturées changent.

```typescript
import { tilia, watch } from "tilia";

const exercise = tilia({ result: "pending" });
const alice = tilia({ score: 0 });

watch(
  // Fonction de capture : définit les dépendances
  () => exercise.result,
  
  // Fonction d'effet : appelée quand les dépendances changent
  (result) => {
    if (result === "pass") {
      alice.score++;  // Cette modification n'est PAS observée
    } else if (result === "fail") {
      alice.score--;
    }
  }
);

exercise.result = "pass";  // ✨ Déclenche l'effet
alice.score = 100;         // 😴 Ne déclenche PAS l'effet
```

**Différence clé avec `observe()` :**
- Dans `watch`, les modifications dans l'effet ne déclenchent pas de ré-exécution
- Utile pour éviter les boucles infinies dans les cas complexes

</section>

<a id="batch"></a>

<section class="doc batch wide-comment">

### batch

Groupez plusieurs mises à jour pour éviter les notifications redondantes. Cela peut être nécessaire pour gérer des cycles de mise à jour complexes—comme dans les jeux—où les changements d'état atomiques sont essentiels.

**💡 Pro tip** `batch` n'est pas requis dans `computed`, `source`, `store`, `observe` ou `watch` où les notifications sont déjà bloquées. {.pro}

```typescript
import { batch } from "tilia";

network.subscribe((updates) => {
  batch(() => {
    for (const update in updates) {
      app.process(update);
    }
  });
  // ✨ Les notifications se produisent ici
});
```

</section>

<a id="computed"></a>

<section class="doc computed wide-comment">

### computed

Retourne une valeur calculée à insérer dans un objet Tilia.

La valeur est calculée quand la clé est lue (**pull** réactivité) et est détruite (invalidée) quand une valeur observée change.

```typescript
import { computed } from "tilia";

const globals = tilia({ now: dayjs() });

setInterval(() => (globals.now = dayjs()), 1000 * 60);

const alice = tilia({
  name: "Alice",
  birthday: dayjs("2015-05-24"),
  // La valeur 'age' est toujours à jour
  age: computed(() => globals.now.diff(alice.birthday, "year")),
});
```

**💡 Pro tip:** Le computed peut être créé n'importe où mais ne devient actif qu'une fois inséré dans un objet Tilia. {.pro}

Une fois qu'une valeur est calculée, elle se comporte exactement comme une valeur régulière jusqu'à ce qu'elle expire en raison d'un changement dans les dépendances. Cela signifie qu'il y a presque zéro overhead pour les valeurs calculées agissant comme des getters.

#### Chaînage de computed

Les valeurs `computed` peuvent dépendre d'autres valeurs `computed` :

```typescript
const store = tilia({
  items: [
    { price: 100, quantity: 2 },
    { price: 50, quantity: 1 },
  ],
  discount: 0.1,  // 10% de réduction
  
  subtotal: computed(() => 
    store.items.reduce((sum, item) => sum + item.price * item.quantity, 0)
  ),
  
  discountAmount: computed(() => 
    store.subtotal * store.discount
  ),
  
  total: computed(() => 
    store.subtotal - store.discountAmount
  ),
});

console.log(store.total);  // 225 (250 - 25)

store.discount = 0.2;  // Change la réduction à 20%
console.log(store.total);  // 200 (250 - 50)
```

</section>

## Programmation Réactive Fonctionnelle {.frp}

✨ **Architecte arc-en-ciel**, tilia a <span>7</span> fonctions supplémentaires pour vous ! ✨ {.rainbow}

Avant d'introduire chacune, voici un aperçu. {.subtitle}

<a id="patterns"></a>

<section class="doc patterns wide-comment summary frp">

| Fonction                | Cas d'usage                                               | Paramètre tree | Valeur précédente | Setter | Valeur retournée |
| :---------------------- | :-------------------------------------------------------- | :------------: | :---------------: | :----: | ---------------- |
| [`computed`](#computed) | Valeur calculée depuis des sources externes               |     ❌ Non      |       ❌ Non       | ❌ Non  | ✅ Oui            |
| [`carve`](#carve)       | Calcul cross-propriété                                    |     ✅ Oui      |       ❌ Non       | ❌ Non  | ✅ Oui            |
| [`source`](#source)     | Mises à jour externes/async                               |     ❌ Non      |       ✅ Oui       | ✅ Oui  | ❌ Non            |
| [`store`](#store)       | Machine à états/logique d'init                            |     ❌ Non      |       ❌ Non       | ✅ Oui  | ✅ Oui            |
| [`readonly`](#readonly) | Éviter le tracking sur données (grandes) en lecture seule |                |                   |        |                  |

Et quelques sucres syntaxiques :

<table>
    <thead>
        <tr>
            <th style="align:left">Fonction</th>
            <th style="text-align:left">Cas d'usage</th>
            <th style="text-align:left">Implémentation</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="text-align:left"><a href="#signal"><code>signal</code></a></td>
            <td style="text-align:left">Créer une valeur mutable et un setter</td>
            <td style="text-align:left">

```typescript
const signal = (v) => {
  const s = tilia({ value: v })
  return [s, (v) => { s.value = v }]
}
```

  </td>
        </tr>
        <tr>
            <td style="text-align:left"><a href="#derived"><code>derived</code></a></td>
            <td style="text-align:left">Crée une valeur calculée basée sur d'autres valeurs tilia</td>
            <td style="text-align:left">

```typescript
const derived = (fn) =>
  signal(computed(fn))
```
            
  </td>
        </tr>
        <tr>
            <td style="text-align:left"><a href="#lift"><code>lift</code></a></td>
            <td style="text-align:left">Déroule un signal pour l'insérer dans un objet tilia</td>
            <td style="text-align:left">
            
```typescript
const lift = (s) => 
  computed(() => s.value)
```
            
  </td>
        </tr>
    </tbody>
</table>

</section>

<a id="source"></a>

<section class="doc frp wide-comment source">

### source

Retourne une source réactive à insérer dans un objet Tilia.

Une source est similaire à un computed, mais elle reçoit une valeur initiale et une fonction setter et ne retourne pas de valeur. Le callback de setup est appelé lors de la première lecture de valeur et chaque fois qu'une valeur observée change. La valeur initiale est utilisée avant le premier appel à set.

```typescript
const app = tilia({
  // Rechargeur de données async (setup se ré-exécutera quand l'âge d'alice change)
  social: source(
    { t: "Loading" },
    (_previous, set) => {
      if (alice.age > 13) {
        fetchData(set);
      } else {
        set({ t: "NotAvailable" });
      }
    }
  ),
  // Abonnement à un événement async (statut en ligne)
  online: source(false, subscribeOnline),
});
```

**Caractéristiques de `source()` :**
- Reçoit la valeur précédente comme premier argument du callback
- Le callback est ré-exécuté quand ses dépendances changent
- Idéal pour les loaders de données réactifs

</section>

<a id="store"></a>

<section class="doc computed wide-comment store">

### store

Retourne une valeur calculée, créée avec un **setter** qui sera inséré dans un objet Tilia.

```typescript
import { computed } from "tilia";

const app = tilia({
  auth: store(loggedOut),
});

function loggedOut(set: Setter<Auth>): Auth {
  return {
    t: "LoggedOut",
    login: (user: User) => set(loggedIn(set, user)),
  };
}

function loggedIn(set: Setter<Auth>, user: User): Auth {
  return {
    t: "LoggedIn",
    user: User,
    logout: () => set(loggedOut(set)),
  };
}
```

**💡 Pro tip:** `store` est un pattern très puissant qui facilite l'initialisation d'une feature dans un état spécifique (pour les tests par exemple). {.pro}

</section>

<a id="readonly"></a>

<section class="doc frp wide-comment readonly">

### readonly

Un petit helper pour marquer un champ comme readonly (et ainsi ne pas tracker les changements de ses champs) :

```typescript
import { type Readonly, readonly } from "tilia";

const app = tilia({
  form: readonly(bigStaticData),
});

// Original `bigStaticData` sans tracking
const data = app.form.data;

// 🚨 'set' on proxy: trap returned falsish for property 'data'
app.form.data = { other: "data" };
```

</section>

<a id="signal"></a>

<section class="doc frp wide-comment signal">

### signal

Un signal représente une valeur unique et changeante de n'importe quel type.

C'est un petit wrapper autour de `tilia` pour exposer une valeur unique et changeante ainsi qu'un setter.

```typescript
type Signal<T> = { value: T };

const signal = (v) => {
  const s = tilia({ value: v })
  return [s, (v) => { s.value = v }]
}

// Usage

const [s, set] = signal(0)

set(1)
console.log(s.value)
```

**🌱 Petit conseil**: Utilisez `signal` pour les calculs d'état et exposez-les avec `tilia` et `lift` pour refléter votre domaine :

```typescript
// ✅ Orienté domaine
const [authenticated, setAuthenticated] = signal(false)

const app = tilia({
  authenticated: lift(authenticated)
  now: store(runningTime),
});

if (app.authenticated) {
}
```

</section>

<a id="derived"></a>

<section class="doc frp wide-comment derived">

### derived

Crée un signal représentant une valeur calculée. C'est similaire à l'argument `derived` de `carve`, mais en dehors d'un objet.

```typescript
function derived<T>(fn: () => T): Signal<T> {
  return signal(computed(fn));
}

// Usage

const s = signal(0);

const double = derived(() => s.value * 2);
console.log(double.value);
```

</section>

<a id="lift"></a>

<section class="doc frp wide-comment lift">

### lift

Crée une valeur `computed` qui reflète la valeur actuelle d'un signal à insérer dans un objet Tilia. Utilisez signal et lift pour créer un état privé et exposer des valeurs en lecture seule.

```typescript
// Implémentation de lift
function lift<T>(s: Signal<T>): T {
  return computed(() => s.value);
}

// Usage
type Todo = {
  readonly title: string;
  setTitle: (title: string) => void;
};

const (title, setTitle) = signal("");

const todo = tilia({
  title: lift(title),
  setTitle,
});
```

</section>

<a id="carve"></a>

## <span>✨</span> Carving <span>✨</span> {.carve}

<section class="doc computed wide-comment carve">

### carve

C'est là que Tilia brille vraiment. Il vous permet de construire une feature orientée domaine, autonome, facile à tester et à réutiliser.

```typescript
const feature = carve(({ derived }) => { ... fields })
```

La fonction `derived` dans l'argument de carve est comme un `computed` mais avec l'objet lui-même comme premier paramètre.

#### Exemple

```typescript
import { carve, source } from "tilia";

// Une fonction pure pour trier les todos, facile à tester isolément.
function list(todos: Todos) {
  const compare = todos.sort === "by date"
    ? (a, b) => a.createdAt.localeCompare(b.createdAt)
    : (a, b) => a.title.localeCompare(b.title);
  return [...todos.data].sort(compare);
}

// Une fonction pure pour basculer un todo, également facilement testable.
function toggle({ data, repo }: Todos) {
  return (id: string) => {
    const todo = data.find(t => t.id === id);
    if (todo) {
      todo.completed = !todo.completed;
      repo.save(todo)
    } else {
      throw new Error(`Todo ${id} not found`);
    }
  };
}

// Injection de la dépendance "repo"
function makeTodos(repo: Repo) {
  // ✨ Sculpter la feature todos ✨
  return carve({ derived }) => ({
    sort: "by date",
    list: derived(list),
    data: source([], repo.fetchTodos),
    toggle: derived(toggle),
    repo,
  });
}
```

**💡 Pro tip:** Le carving est un moyen puissant de construire des features orientées domaine et autonomes. Extraire la logique en fonctions pures (comme `list` et `toggle`) facilite les tests et la réutilisation. {.pro}

#### Dérivation récursive (machines à états)

Pour la dérivation récursive (comme les machines à états), utilisez `source` :

```typescript
derived((tree) => source(initialValue, machine));
```

Cela vous permet de créer un état dynamique ou auto-référentiel qui réagit aux changements dans d'autres parties de l'arbre.

<div class="text-center text-3xl text-black hue-rotate-230">💡</div>

#### Différence avec `computed`

- Utilisez `computed` pour les valeurs dérivées pures qui ne dépendent **pas** de l'objet entier.
- Utilisez `derived` (via `carve`) quand vous avez besoin d'accéder à l'objet réactif complet pour la logique cross-propriété ou les méthodes.

Regardez <a href="https://github.com/tiliajs/tilia/blob/main/todo-app-ts/src/domain/feature/todos/todos.ts">todos.ts</a> pour un exemple d'utilisation de `carve` pour construire la feature todos.

</section>

<a id="react"></a>

## Intégration React {.react}

<section class="doc react useTilia">

### useTilia <small>(React Hook)</small> {.useTilia}

#### Installation

```bash
npm install @tilia/react
```

Insérez `useTilia` en haut des composants React qui consomment des valeurs tilia.

```typescript
import { useTilia } from "@tilia/react";

function App() {
  useTilia();

  if (alice.age >= 13) {
    return <SocialMediaApp />;
  } else {
    return <NormalApp />;
  }
}
```

Le composant App se re-rendra maintenant quand `alice.age` change parce que "age" a été lu depuis "alice" pendant le dernier render.

</section>

<section class="doc react useTilia">

### leaf <small>(React Higher Order Component)</small> {.leaf}

C'est la méthode **recommandée** pour créer des composants réactifs. Comparé à `useTilia`, ce tracking est exact grâce au tracking propre début/fin de la phase de render qui n'est pas faisable avec les hooks.

#### Installation

```bash
npm install @tilia/react
```

Enveloppez votre composant avec `leaf` :

```typescript
import { leaf } from "@tilia/react";

// Utilisez une fonction nommée pour avoir des noms de composants appropriés dans React dev tools.
const App = leaf(function App() {
  if (alice.age >= 13) {
    return <SocialMediaApp />;
  } else {
    return <NormalApp />;
  }
});
```

Le composant App se re-rendra maintenant quand `alice.age` change parce que "age" a été lu depuis "alice" pendant le dernier render.

</section>

<a id="useComputed"></a>

<section class="doc react useComputed">

### useComputed <small>(React Hook)</small> {.useComputed}

`useComputed` vous permet de calculer une valeur et de ne re-rendre que si le résultat change.

```typescript
import { useTilia, useComputed } from "@tilia/react";

function TodoView({ todo }: { todo: Todo }) {
  useTilia();

  const selected = useComputed(() => app.todos.selected.id === todo.id);

  return <div className={selected.value ? "text-pink-200" : ""}>...</div>;
}
```

Avec ce helper, TodoView ne dépend pas de `app.todos.selected.id` mais de `selected.value`. Cela empêche le composant de re-rendre à chaque changement du todo sélectionné.

</section>

## Référence Technique Approfondie {.api}

<a id="architecture"></a>

<section class="doc computed wide-comment">

### Architecture Interne

#### Structure du Proxy Handler

Voici une représentation simplifiée du handler Proxy utilisé par Tilia :

```typescript
// Simplifié pour la compréhension
const createHandler = (context: TiliaContext) => ({
  get(target: object, key: string | symbol, receiver: unknown) {
    // 1. Ignorer les symboles et propriétés internes
    if (typeof key === "symbol" || key.startsWith("_")) {
      return Reflect.get(target, key, receiver);
    }
    
    // 2. Enregistrer la dépendance si un observer est actif
    if (context.currentObserver !== null) {
      context.addDependency(context.currentObserver, target, key);
    }
    
    // 3. Récupérer la valeur
    const value = Reflect.get(target, key, receiver);
    
    // 4. Si c'est un objet, le wrapper récursivement
    if (isObject(value) && !isProxy(value)) {
      return createProxy(value, context);
    }
    
    // 5. Si c'est un computed, l'exécuter
    if (isComputed(value)) {
      return executeComputed(value, context);
    }
    
    return value;
  },
  
  set(target: object, key: string | symbol, value: unknown, receiver: unknown) {
    const oldValue = Reflect.get(target, key, receiver);
    
    // 1. Effectuer la modification
    const result = Reflect.set(target, key, value, receiver);
    
    // 2. Notifier si la valeur a changé
    if (!Object.is(oldValue, value)) {
      context.notify(target, key);
    }
    
    return result;
  },
  
  deleteProperty(target: object, key: string | symbol) {
    const result = Reflect.deleteProperty(target, key);
    
    // Notifier de la suppression
    if (result) {
      context.notify(target, key);
    }
    
    return result;
  },
  
  ownKeys(target: object) {
    // Tracker l'itération sur les clés
    if (context.currentObserver !== null) {
      context.addDependency(context.currentObserver, target, KEYS_SYMBOL);
    }
    return Reflect.ownKeys(target);
  },
});
```

#### Cycle de vie d'un computed

```
┌─────────────────────────────────────────────────────────────┐
│                    ÉTAT INITIAL                              │
│  computed créé mais pas encore exécuté                       │
│  cache = EMPTY, valid = false                                │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (première lecture)
┌─────────────────────────────────────────────────────────────┐
│                    EXÉCUTION                                 │
│  1. currentObserver = ce computed                            │
│  2. Exécution de la fonction                                 │
│  3. Dépendances enregistrées pendant l'exécution            │
│  4. cache = résultat, valid = true                          │
│  5. currentObserver = null                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (lectures suivantes)
┌─────────────────────────────────────────────────────────────┐
│                    CACHE HIT                                 │
│  valid = true → retourne cache directement                  │
│  Aucun recalcul                                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (dépendance change)
┌─────────────────────────────────────────────────────────────┐
│                    INVALIDATION                              │
│  1. SET détecté sur une dépendance                          │
│  2. valid = false                                            │
│  3. Notification propagée aux observateurs                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (prochaine lecture)
┌─────────────────────────────────────────────────────────────┐
│                    RE-EXÉCUTION                              │
│  Même processus que EXÉCUTION                                │
│  Nouvelles dépendances potentiellement différentes          │
└─────────────────────────────────────────────────────────────┘
```

#### Forest Mode

Tilia supporte le "Forest Mode" où plusieurs objets `tilia()` séparés peuvent être observés ensemble :

```typescript
const alice = tilia({ name: "Alice", age: 10 });
const bob = tilia({ name: "Bob", age: 12 });

// Un seul observe qui dépend de DEUX arbres
observe(() => {
  console.log(`${alice.name} a ${alice.age} ans`);
  console.log(`${bob.name} a ${bob.age} ans`);
});

alice.age = 11;  // ✨ Déclenche l'observe
bob.age = 13;    // ✨ Déclenche aussi l'observe
```

Ce fonctionnement est possible grâce au contexte global partagé qui maintient les dépendances de tous les arbres.

</section>

<a id="glue-zone"></a>

<section class="doc errors wide-comment">

### Le "Glue Zone" et la Sécurité (v4)

#### Le problème des Orphan Computations

Avant la v4, il était possible de créer un `computed` en dehors d'un objet Tilia, ce qui causait des erreurs obscures :

```typescript
// ❌ DANGER : computed créé "dans le vide"
const trouble = computed(() => count.value * 2);

// Plus tard, accès en dehors d'un contexte réactif
const crash = trouble * 2;  // 💥 Erreur obscure !
```

#### La "Glue Zone"

La "Glue Zone" est la zone dangereuse où une définition de computation existe sans être attachée à un objet. En v4, Tilia ajoute des protections pour éviter ce problème.

```typescript
// AVANT (Glue Zone - dangereux)
const computed_def = computed(() => x.value * 2);
// 'computed_def' est un "fantôme" - ni une valeur, ni attaché à un objet

// APRÈS (insertion dans un objet - sûr)
const obj = tilia({
  double: computed(() => x.value * 2)  // ✅ Créé directement dans l'objet
});
```

#### Safety Proxies (v4)

En v4, les définitions de computation (`computed`, `source`, `store`) sont enveloppées dans un Safety Proxy :

- **Dans un contexte réactif** (tilia/carve) : le proxy s'unwrap transparemment
- **En dehors** : le proxy **lance une erreur descriptive**

```typescript
const [count, setCount] = signal(0);

// ❌ Création d'un orphan
const orphan = computed(() => count.value * 2);

// 🛡️ v4 Protection: Lance une erreur claire
const result = orphan * 2;
// Error: "Orphan computation detected. computed/source/store must be
// created directly inside a tilia or carve object."
```

#### Règle d'or

> **NE JAMAIS** assigner le résultat d'un `computed`, `source` ou `store` à une variable intermédiaire.  
> **TOUJOURS** les définir directement dans un objet `tilia()` ou `carve()`.

```typescript
// ❌ Mauvais
const myComputed = computed(() => ...);
const obj = tilia({ value: myComputed });

// ✅ Bon
const obj = tilia({
  value: computed(() => ...)
});
```

</section>

<a id="flush-batching"></a>

<section class="doc batch wide-comment">

### Stratégie de Flush et Batching

#### Deux comportements selon le contexte

Le moment où Tilia notifie les observateurs dépend de **où** la modification a lieu :

| Contexte                           | Comportement       | Exemple                                                 |
| ---------------------------------- | ------------------ | ------------------------------------------------------- |
| **Hors observation**               | Flush **immédiat** | Code dans un event handler, setTimeout, etc.            |
| **Dans un contexte d'observation** | Flush **différé**  | Dans `computed`, `observe`, `watch`, `leaf`, `useTilia` |

#### Hors contexte d'observation : flush immédiat

Quand vous modifiez une valeur **en dehors** d'un contexte d'observation, chaque modification déclenche **immédiatement** une notification :

```typescript
const state = tilia({ a: 1, b: 2 });

observe(() => {
  console.log(`a=${state.a}, b=${state.b}`);
});
// Output: "a=1, b=2"

// Hors contexte d'observation (ex: dans un event handler)
state.a = 10;
// ⚡ Notification IMMÉDIATE !
// Output: "a=10, b=2"

state.b = 20;
// ⚡ Notification IMMÉDIATE !
// Output: "a=10, b=20"
```

#### Le problème des états transitoires incohérents

Ce comportement peut causer des problèmes quand plusieurs propriétés doivent changer ensemble de manière cohérente :

```typescript
const rect = tilia({
  width: 100,
  height: 50,
  ratio: computed(() => rect.width / rect.height),
});

observe(() => {
  console.log(`Dimensions: ${rect.width}x${rect.height}, ratio: ${rect.ratio}`);
});
// Output: "Dimensions: 100x50, ratio: 2"

// On veut passer à 200x100 (même ratio)
rect.width = 200;
// ⚠️ État transitoire incohérent !
// Output: "Dimensions: 200x50, ratio: 4"  ← ratio incorrect !

rect.height = 100;
// Output: "Dimensions: 200x100, ratio: 2"  ← correct maintenant
```

L'observateur a vu un état intermédiaire où le ratio était de 4, ce qui n'était jamais l'intention.

#### batch() : la solution pour les modifications groupées

`batch()` permet de regrouper plusieurs modifications et de ne notifier qu'une seule fois à la fin :

```typescript
import { batch } from "tilia";

// ✅ Avec batch : une seule notification cohérente
batch(() => {
  rect.width = 200;
  rect.height = 100;
  // Aucune notification pendant le batch
});
// ✨ Une seule notification ici
// Output: "Dimensions: 200x100, ratio: 2"
```

**Cas d'usage typiques pour `batch()` :**
- Event handlers qui modifient plusieurs propriétés
- Callbacks de WebSocket/SSE avec mises à jour multiples
- Initialisation de plusieurs valeurs

#### Dans un contexte d'observation : flush différé automatique

À l'intérieur d'un callback `computed`, `observe`, `watch`, ou d'un composant avec `leaf`/`useTilia`, les notifications sont **automatiquement différées**. Pas besoin d'utiliser `batch()` :

```typescript
const state = tilia({
  items: [],
  processedCount: 0,
});

observe(() => {
  // Dans un contexte d'observation, les modifications sont batchées
  for (const item of incomingItems) {
    state.items.push(item);
    state.processedCount++;
    // Pas de notification ici, même si des observateurs regardent ces valeurs
  }
  // ✨ Notifications à la fin du callback
});
```

#### Mutations récursives dans observe

Si vous modifiez une valeur observée **par le même callback** dans `observe`, celui-ci sera planifié pour une ré-exécution après la fin de l'exécution actuelle :

```typescript
observe(() => {
  console.log("Value:", state.value);
  
  if (state.value < 5) {
    state.value++;  // Planifie une nouvelle exécution
  }
});

// Output:
// "Value: 0"
// "Value: 1"
// "Value: 2"
// "Value: 3"
// "Value: 4"
// "Value: 5"
```

**⚠️ Attention :** Cette fonctionnalité est puissante mais peut créer des boucles infinies si mal utilisée.

</section>

<a id="mutations-computed"></a>

<section class="doc computed wide-comment">

### Mutations dans computed : risque de boucle infinie

Le principal danger des mutations dans un `computed` est le risque de **boucle infinie** : si le `computed` lit la valeur qu'il modifie, il s'invalide lui-même et tourne en boucle.

```typescript
const state = tilia({
  items: [] as number[],
  
  // ❌ DANGER : le computed lit ET modifie 'items'
  count: computed(() => {
    const len = state.items.length;  // Lecture de 'items'
    state.items.push(len);           // Écriture dans 'items' → invalide le computed !
    return len;                      // → Recalcul → Lecture → Écriture → ∞
  }),
});

// Accéder à state.count provoque une boucle infinie !
```

**Le problème :** Le `computed` observe `items`, puis le modifie, ce qui l'invalide et provoque un nouveau calcul, qui observe à nouveau, modifie à nouveau, etc.

#### Solution : utiliser `watch` pour séparer observation et mutation

`watch` sépare clairement :
- La **phase d'observation** (premier callback) : trackée, définit les dépendances
- La **phase de mutation** (second callback) : sans tracking, pas de risque de boucle

```typescript
const state = tilia({
  count: 0,
  history: [] as number[],
});

// ✅ BON : watch sépare observation et mutation
watch(
  () => state.count,              // Observation : trackée
  (count) => {
    state.history.push(count);    // Mutation : pas de tracking ici
  }
);

state.count = 1;  // history devient [1]
state.count = 2;  // history devient [1, 2]
```

Avec `watch`, la mutation dans le second callback n'est **pas trackée**, donc elle ne peut pas créer de boucle même si elle lit et modifie les mêmes valeurs.

</section>

<a id="garbage-collection"></a>

<section class="doc computed wide-comment">

### Garbage Collection

#### Ce que gère le GC natif de JavaScript

Le garbage collector natif de JavaScript gère très bien la libération des **objets trackés** qui ne sont plus utilisés en mémoire. Si un objet `tilia({...})` n'est plus référencé nulle part, JavaScript le libère automatiquement, ainsi que toutes ses dépendances internes.

Vous n'avez rien à faire pour cela : c'est le comportement standard de JavaScript.

#### Ce que gère le GC de Tilia

Pour chaque propriété observée, Tilia maintient une **liste de watchers**. Quand un watcher est "cleared" (par exemple, quand un composant React se démonte), il est retiré de la liste, mais la liste elle-même (même vide) reste attachée à la propriété.

Ces listes vides représentent très peu de données, mais Tilia les nettoie périodiquement :

```typescript
import { make } from "tilia";

// Configuration du seuil GC
const ctx = make({
  gc: 100,  // Déclenche le nettoyage après 100 watchers cleared
});

// Le seuil par défaut est 50
```

#### Quand le nettoyage se déclenche

1. Un watcher est "cleared" (composant démonté, etc.)
2. Le compteur `clearedWatchers` s'incrémente
3. Si `clearedWatchers >= gc`, nettoyage de la liste des watchers
4. `clearedWatchers` reset à 0

#### Configuration selon l'application

```typescript
// Application avec beaucoup de composants dynamiques (listes, onglets, modales)
const ctx = make({ gc: 200 });

// Application plus stable avec peu de montages/démontages
const ctx = make({ gc: 30 });
```

En pratique, le seuil par défaut (50) convient à la plupart des applications.

</section>

<a id="error-handling"></a>

<section class="doc errors wide-comment">

### Gestion des Erreurs

#### Erreurs dans computed et observe

Quand une exception est levée dans un callback `computed` ou `observe`, Tilia adopte une stratégie de **report d'erreur** pour éviter de bloquer l'application :

1. L'exception est **capturée** immédiatement
2. L'erreur est **loguée** dans `console.error` avec une stack trace nettoyée
3. L'observer fautif est **nettoyé** (cleared) pour éviter de bloquer le système
4. L'erreur est **relancée** à la fin du prochain flush

```typescript
const state = tilia({
  value: 0,
  computed: computed(() => {
    if (state.value === 42) {
      throw new Error("La réponse universelle est interdite !");
    }
    return state.value * 2;
  }),
});

observe(() => {
  console.log("Computed:", state.computed);
});

// Tout fonctionne
state.value = 10;  // Log: "Computed: 20"

// Déclenche une erreur
state.value = 42;
// 1. L'erreur est loguée immédiatement dans console.error
// 2. L'observer est nettoyé
// 3. L'erreur est relancée à la fin du flush
```

#### Pourquoi différer l'erreur ?

Ce comportement permet de :

1. **Ne pas bloquer les autres observers** : Si un observer crashe, les autres continuent de fonctionner
2. **Garder l'application stable** : Le système réactif n'est pas verrouillé par une erreur
3. **Logger immédiatement** : L'erreur apparaît dans la console dès qu'elle se produit
4. **Propager l'erreur** : L'exception remonte quand même pour être gérée par l'application

#### Stack trace nettoyée

Pour faciliter le débogage, Tilia nettoie la stack trace en retirant les lignes internes de la bibliothèque. Vous voyez directement où l'erreur s'est produite dans **votre** code :

```
Exception thrown in computed or observe
    at myComputed (src/domain/feature.ts:42:15)
    at handleClick (src/components/Button.tsx:18:5)
```

#### Bonnes pratiques

```typescript
// ✅ Gérer les cas d'erreur dans le computed
const state = tilia({
  data: computed(() => {
    try {
      return riskyOperation();
    } catch (e) {
      console.error("Opération échouée:", e);
      return { error: true, message: e.message };
    }
  }),
});

// ✅ Utiliser des valeurs par défaut
const state = tilia({
  user: computed(() => fetchedUser ?? { name: "Anonyme" }),
});
```

</section>

<div class="flex flex-row space-x-4 justify-center items-center w-full gap-12">
  <a href="/compare"
    class="bg-gradient-to-r from-green-400 to-blue-500 px-6 py-3 rounded-full font-bold hover:scale-105 transform transition">
    Comparaison avec...
  </a>
  <a href="https://github.com/tiliajs/tilia"
    class="border-2 border-white/50 px-6 py-3 rounded-full font-bold hover:bg-white/20 transition">
    GitHub
  </a>
</div>

<div class="bg-black/20 backdrop-blur-lg rounded-xl md:p-8 p-4 border border-white/20 my-8">
  <h2 class="text-3xl font-bold mb-6 text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-blue-500">
    Fonctionnalités Principales
  </h2>
  <div class="grid lg:grid-cols-2 lg:gap-6 gap-3">
    <div class="space-y-3">
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span class="font-bold text-green-300">Zéro dépendances</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Optimisé pour la stabilité et la vitesse</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Réactivité hautement granulaire</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Combine la réactivité <strong>pull</strong> et <strong>push</strong></span>
      </div>
    </div>
    <div class="space-y-3">
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Le tracking suit les objets déplacés ou copiés</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Compatible avec ReScript et TypeScript</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Calculs optimisés (pas de recalcul, traitement par batch)</span>
      </div>
      <div class="flex items-center space-x-2">
        <span class="text-green-400">✓</span>
        <span>Empreinte réduite (8KB) ✨</span>
      </div>
    </div>
  </div>
</div>

</main>
