import { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma';

export async function syncRoutes(app: FastifyInstance) {
    app.post('/', async (request: any, reply) => {
        const { customers, products, orders } = request.body;

        const results = { customers: 0, products: 0, orders: 0 };

        if (customers) {
            for (const c of customers) {
                // Omit relations if any
                const { prices, orders, ...data } = c;
                await prisma.customer.upsert({
                    where: { id: data.id },
                    update: { ...data, updatedAt: new Date() },
                    create: { ...data, updatedAt: new Date() }
                });
                results.customers++;
            }
        }

        if (products) {
            for (const p of products) {
                const { orderItems, customerPrices, ...data } = p;
                await prisma.product.upsert({
                    where: { id: data.id },
                    update: { ...data, updatedAt: new Date() },
                    create: { ...data, updatedAt: new Date() }
                });
                results.products++;
            }
        }

        // Orders sync is trickier due to items. For now assume full order object
        if (orders) {
            for (const o of orders) {
                const { items, customer, ...data } = o;
                // Check if exists
                const existing = await prisma.order.findUnique({ where: { id: data.id } });
                if (!existing) {
                    await prisma.order.create({
                        data: {
                            ...data,
                            items: {
                                create: items.map((i: any) => ({
                                    productId: i.productId,
                                    qtyKg: i.qtyKg,
                                    price: i.price,
                                    total: i.total
                                }))
                            }
                        }
                    });
                    results.orders++;
                }
            }
        }

        return results;
    });

    app.get('/changes', async (request: any, reply) => {
        const { since } = request.query;
        const date = since ? new Date(since) : new Date(0);

        const customers = await prisma.customer.findMany({ where: { updatedAt: { gt: date } } });
        const products = await prisma.product.findMany({ where: { updatedAt: { gt: date } } });
        const orders = await prisma.order.findMany({ where: { updatedAt: { gt: date } } });

        return { customers, products, orders };
    });
}
