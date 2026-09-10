import { Router } from 'express';
import { register, login, logout, refreshSession, getProfile, updateProfile, googleLogin, appleLogin, deleteAccount, sendVerificationCode, pruneStaleData } from '../controllers/auth.controller.js';
import { authenticateToken } from '../middlewares/auth.js';

const router = Router();

router.post('/send-code', sendVerificationCode);
router.post('/register', register);
router.post('/login', login);
router.post('/refresh', refreshSession);
router.post('/logout', authenticateToken as any, logout as any);
router.get('/profile', authenticateToken as any, getProfile as any);
router.patch('/profile', authenticateToken as any, updateProfile as any);
router.post('/google', googleLogin);
router.post('/apple', appleLogin);
router.delete('/delete-account', authenticateToken as any, deleteAccount as any);

router.post('/prune-stale-data', authenticateToken as any, pruneStaleData as any);

export default router;
