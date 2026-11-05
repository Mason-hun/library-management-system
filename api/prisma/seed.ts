import dotenv from 'dotenv';
import path from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

// Load environment variables from api/.env or fallback to repository root .env
dotenv.config();
dotenv.config({ path: path.resolve(process.cwd(), '../.env') });

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
});

const prisma = new PrismaClient({ adapter });

const genres = [
  {
    name: 'Fiction',
    description: 'Imaginative stories, novels, and literary works.',
  },
  {
    name: 'Science',
    description: 'Books exploring scientific knowledge, astronomy, and discovery.',
  },
  {
    name: 'Philosophy',
    description: 'Works exploring fundamental questions about existence, ethics, and knowledge.',
  },
  {
    name: 'History',
    description: 'Chronicles documenting world events, civilizations, and historical analyses.',
  },
];

const books = [
  {
    title: 'The Alchemist',
    author: 'Paulo Coelho',
    isbn: '9780061122415',
    publishedYear: 1988,
    genre: 'Fiction',
  },
  {
    title: '1984',
    author: 'George Orwell',
    isbn: '9780451524935',
    publishedYear: 1949,
    genre: 'Fiction',
  },
  {
    title: 'The Name of the Wind',
    author: 'Patrick Rothfuss',
    isbn: '9780756404741',
    publishedYear: 2007,
    genre: 'Fiction',
  },
  {
    title: 'Dune',
    author: 'Frank Herbert',
    isbn: '9780441172719',
    publishedYear: 1965,
    genre: 'Fiction',
  },
  {
    title: 'Siddhartha',
    author: 'Hermann Hesse',
    isbn: '9780553208849',
    publishedYear: 1922,
    genre: 'Philosophy',
  },
  {
    title: 'Meditations',
    author: 'Marcus Aurelius',
    isbn: '9780812968255',
    publishedYear: 180,
    genre: 'Philosophy',
  },
  {
    title: 'The Republic',
    author: 'Plato',
    isbn: '9780140449143',
    publishedYear: -375,
    genre: 'Philosophy',
  },
  {
    title: 'The Kybalion',
    author: 'Three Initiates',
    isbn: '9781585420590',
    publishedYear: 1908,
    genre: 'Philosophy',
  },
  {
    title: 'Beyond Good and Evil',
    author: 'Friedrich Nietzsche',
    isbn: '9780140449235',
    publishedYear: 1886,
    genre: 'Philosophy',
  },
  {
    title: 'Cosmos',
    author: 'Carl Sagan',
    isbn: '9780345539434',
    publishedYear: 1980,
    genre: 'Science',
  },
  {
    title: 'A Brief History of Time',
    author: 'Stephen Hawking',
    isbn: '9780553380163',
    publishedYear: 1988,
    genre: 'Science',
  },
  {
    title: 'The Selfish Gene',
    author: 'Richard Dawkins',
    isbn: '9780198788607',
    publishedYear: 1976,
    genre: 'Science',
  },
  {
    title: 'The Gene: An Intimate History',
    author: 'Siddhartha Mukherjee',
    isbn: '9781476733500',
    publishedYear: 2016,
    genre: 'Science',
  },
  {
    title: 'Sapiens: A Brief History of Humankind',
    author: 'Yuval Noah Harari',
    isbn: '9780062316097',
    publishedYear: 2011,
    genre: 'History',
  },
  {
    title: 'Guns, Germs, and Steel',
    author: 'Jared Diamond',
    isbn: '9780393317558',
    publishedYear: 1997,
    genre: 'History',
  },
];

async function main() {
  console.log('Seeding genres...');
  const genreMap = new Map<string, number>();

  for (const genre of genres) {
    const upserted = await prisma.genre.upsert({
      where: { name: genre.name },
      update: { description: genre.description },
      create: genre,
    });
    genreMap.set(upserted.name, upserted.id);
  }
  console.log(`Seeded ${genreMap.size} genres.`);

  console.log('Seeding books...');
  for (const book of books) {
    const genreId = genreMap.get(book.genre);
    if (!genreId) {
      throw new Error(`Genre not found for book: ${book.title}`);
    }

    await prisma.book.upsert({
      where: { isbn: book.isbn },
      update: {
        title: book.title,
        author: book.author,
        publishedYear: book.publishedYear,
        genreId,
      },
      create: {
        title: book.title,
        author: book.author,
        isbn: book.isbn,
        publishedYear: book.publishedYear,
        genreId,
      },
    });
  }
  console.log(`Seeded ${books.length} books with one-to-many genre relations.`);
}

main()
  .catch((error) => {
    console.error('Seeding failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
