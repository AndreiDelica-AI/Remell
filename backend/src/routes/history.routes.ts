import { Router } from 'express';
import { getHistory, searchHistory } from '../controllers/history.controller.js';
import { authenticateToken } from '../middlewares/auth.js';

const router = Router();

router.use(authenticateToken as any);

router.get('/', getHistory as any);
router.get('/search', searchHistory as any);

export default router;
