import { Router } from 'express';
import { getPreferences, updatePreferences } from '../controllers/preferences.controller.js';
import { authenticateToken } from '../middlewares/auth.js';

const router = Router();

router.use(authenticateToken as any);

router.get('/', getPreferences as any);
router.patch('/', updatePreferences as any);

export default router;
