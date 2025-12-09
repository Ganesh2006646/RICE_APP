import { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma';

export async function productRoutes(app: FastifyInstance) {
    app.get('/', async (request, reply) => {
        const products = await prisma.product.findMany();
        return products;
    });

    app.post('/', async (request: any, reply) => {
        const { name, defaultPrice } = request.body;
        const product = await prisma.product.create({
            data: { name, defaultPrice },
        });
        return product;
    });

    app.put('/:id', async (request: any, reply) => {
        const { id } = request.params;
        const { name, defaultPrice } = request.body;
        const product = await prisma.product.update({
            where: { id },
            data: { name, defaultPrice },
        });
        return product;
    });

    app.delete('/:id', async (request: any, reply) => {
        const { id } = request.params;
        await prisma.product.delete({ where: { id } });
        return { success: true };
    });
}
