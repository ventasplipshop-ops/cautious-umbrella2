import jwt from 'jsonwebtoken';

export async function orderAuth(req, res, next) {

    const token =
        req.params.token ||
        req.headers['x-order-token'];

    if (!token) {
        return res.status(401).json({
            error: 'missing_token'
        });
    }

    try {

        const payload = jwt.verify(
            token,
            process.env.ORDER_PUBLIC_SECRET
        );

        // =====================================
        // VALIDAR TIPO
        // =====================================

        if (payload.type !== 'order_public') {
            return res.status(401).json({
                error: 'invalid_token_type'
            });
        }

        // =====================================
        // VALIDAR DATOS MÍNIMOS
        // =====================================

        if (
            !payload.company_id ||
            !payload.lead_id ||
            !payload.created_by
        ) {
            return res.status(401).json({
                error: 'invalid_token_payload'
            });
        }

        // =====================================
        // CONTEXTO PÚBLICO
        // =====================================

        req.orderContext = {
            company_id: payload.company_id,
            lead_id: payload.lead_id,
            created_by: payload.created_by
        };

        next();

    } catch (err) {

        console.error('ORDER AUTH ERROR:', err.message);

        return res.status(401).json({
            error: 'invalid_token'
        });
    }
}