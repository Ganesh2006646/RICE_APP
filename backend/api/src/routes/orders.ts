import { FastifyInstance } from 'fastify';
import { prisma } from '../lib/prisma';
import { generateOrderExcel } from '../services/excel';
import { sendEmailWithAttachment } from '../services/email';

export async function orderRoutes(app: FastifyInstance) {
    app.post('/', async (request: any, reply) => {
        const { id, customerId, agentName, loadingDate, emailTo, notes, totalAmount, items, createdAt, updatedAt } = request.body;

        const order = await prisma.order.create({
            data: {
                id, // Use client-provided ID
                customerId,
                agentName,
                loadingDate: new Date(loadingDate),
                emailTo,
                notes,
                totalAmount,
                createdAt: createdAt ? new Date(createdAt) : undefined,
                updatedAt: updatedAt ? new Date(updatedAt) : undefined,
                items: {
                    create: items.map((item: any) => ({
                        id: item.id, // Use client-provided ID
                        productId: item.productId,
                        bags26: item.bags26,
                        bags10: item.bags10,
                        bags5: item.bags5,
                        qtyKg: item.qtyKg,
                        qtyQtl: item.qtyQtl,
                        ratePerQtl: item.ratePerQtl,
                        amcPercent: item.amcPercent,
                        gstPercent: item.gstPercent,
                        lineAmount: item.lineAmount,
                        amcAmount: item.amcAmount,
                        gstAmount: item.gstAmount,
                        netAmount: item.netAmount,
                        remarks: item.remarks
                    }))
                }
            },
            include: { items: true }
        });
        return order;
    });

    app.get('/:id', async (request: any, reply) => {
        const { id } = request.params;
        const order = await prisma.order.findUnique({
            where: { id },
            include: { customer: true, items: { include: { product: true } } }
        });
        return order;
    });

    app.get('/:id/download', async (request: any, reply) => {
        const { id } = request.params;
        const order = await prisma.order.findUnique({
            where: { id },
            include: { customer: true, items: { include: { product: true } } }
        });
        if (!order) return reply.status(404).send({ error: 'Order not found' });

        const buffer = await generateOrderExcel(order);
        reply.header('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        reply.header('Content-Disposition', `attachment; filename="order-${id}.xlsx"`);
        return reply.send(buffer);
    });

    app.post('/:id/send-email', async (request: any, reply) => {
        const { id } = request.params;
        const { toEmail, subject, message, sendFlag } = request.body;

        if (!sendFlag) return { status: 'skipped' };

        const order = await prisma.order.findUnique({
            where: { id },
            include: { customer: true, items: { include: { product: true } } }
        });
        if (!order) return reply.status(404).send({ error: 'Order not found' });

        const buffer = (await generateOrderExcel(order)) as unknown as Buffer;
        try {
            await sendEmailWithAttachment(toEmail, subject, message, buffer, `order-${id}.xlsx`);
            return { status: 'sent' };
        } catch (e: any) {
            request.log.error(e);
            return reply.status(500).send({ error: 'Failed to send email', details: e.message });
        }
    });

    app.get('/', async (request: any, reply) => {
        const { customerId, from, to } = request.query;
        const where: any = {};
        if (customerId) where.customerId = customerId;
        if (from || to) {
            where.loadingDate = {};
            if (from) where.loadingDate.gte = new Date(from);
            if (to) where.loadingDate.lte = new Date(to);
        }
        return prisma.order.findMany({ where, include: { customer: true }, orderBy: { loadingDate: 'desc' } });
    });
}
