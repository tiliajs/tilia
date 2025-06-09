import { defineCollection, z } from "astro:content";

const docsCollection = defineCollection({
  type: "content",
  schema: z.object({
    title: z.string(),
    description: z.string(),
    order: z.number(),
    category: z.string(),
  }),
});

export const collections = {
  docs: docsCollection,
};
