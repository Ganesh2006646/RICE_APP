import { FastifyInstance } from 'fastify';

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || 'http://ml:8000';

export async function mlRoutes(app: FastifyInstance) {
    app.get('/recommend', async (request: any, reply) => {
        const { customerId } = request.query;
        try {
            const res = await fetch(`${ML_SERVICE_URL}/recommend?customerId=${customerId}`);
            if (!res.ok) throw new Error('ML Service error');
            const data = await res.json();
            return data;
        } catch (e) {
            return { recommendations: [] };
        }
    });
}
