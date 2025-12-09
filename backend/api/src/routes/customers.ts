import { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma';

export async function customerRoutes(app: FastifyInstance) {
    app.get('/', async (request: any, reply) => {
        const { q } = request.query;
        const where: any = q
            ? {
                OR: [
                    { shopName: { contains: q, mode: 'insensitive' } },
                    { ownerName: { contains: q, mode: 'insensitive' } },
                    { phone: { contains: q, mode: 'insensitive' } },
                ],
            }
            : {};
        const customers = await prisma.customer.findMany({ where });
        return customers;
    });

    app.post('/', async (request: any, reply) => {
        const { shopName, ownerName, place, tinGst, phone, email, address, notes } = request.body;
        const customer = await prisma.customer.create({
            data: { shopName, ownerName, place, tinGst, phone, email, address, notes },
        });
        return customer;
    });

    app.put('/:id', async (request: any, reply) => {
        const { id } = request.params;
        const { shopName, ownerName, place, tinGst, phone, email, address, notes } = request.body;
        const customer = await prisma.customer.update({
            where: { id },
            data: { shopName, ownerName, place, tinGst, phone, email, address, notes },
        });
        return customer;
    });

    app.delete('/:id', async (request: any, reply) => {
        const { id } = request.params;
        await prisma.customer.delete({ where: { id } });
        return { success: true };
    });

    // Customer Prices
    app.get('/:id/prices', async (request: any, reply) => {
        const { id } = request.params;
        const prices = await prisma.customerPrice.findMany({
            where: { customerId: id },
            include: { product: true },
        });
        return prices;
    });

    app.post('/:id/prices', async (request: any, reply) => {
        const { id } = request.params;
        const { productId, price } = request.body;
        const customerPrice = await prisma.customerPrice.upsert({
            where: {
                customerId_productId: {
                    customerId: id,
                    productId,
                },
            },
            update: { price },
            create: { customerId: id, productId, price },
        });
        return customerPrice;
    });
}
