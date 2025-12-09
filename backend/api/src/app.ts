import fastify from 'fastify';
import { customerRoutes } from './routes/customers';
import { productRoutes } from './routes/products';
import { orderRoutes } from './routes/orders';
import { syncRoutes } from './routes/sync';
import { mlRoutes } from './routes/ml';

export const buildApp = async () => {
    const app = fastify({ logger: true });

    app.get('/', async () => {
        return { status: 'ok', service: 'RiceAgent Backend' };
    });

    app.register(customerRoutes, { prefix: '/customers' });
    app.register(productRoutes, { prefix: '/products' });
    app.register(orderRoutes, { prefix: '/orders' });
    app.register(syncRoutes, { prefix: '/sync' });
    app.register(mlRoutes, { prefix: '/ml' });

    return app;
};
