import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';
import type { APIContext } from 'astro';
import { SITE } from '../consts';

export async function GET(context: APIContext): Promise<Response> {
  const posts = (await getCollection('writing', ({ data }) => !data.draft)).sort(
    (a, b) => b.data.pubDate.getTime() - a.data.pubDate.getTime(),
  );

  return rss({
    title: SITE.title,
    description: SITE.description,
    site: context.site ?? SITE.url,
    items: posts.map((post) => ({
      title: post.data.title,
      description: post.data.description,
      pubDate: post.data.pubDate,
      link: `/writing/${post.id}/`,
      categories: post.data.tags,
    })),
    customData: `<language>${SITE.locale}</language>`,
  });
}
