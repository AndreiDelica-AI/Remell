import prisma from '../db/client.js';

/**
 * Runs the database pruning routine.
 * Deletes:
 * 1. Soft-deleted user accounts (deletedAt is set and older than 30 days).
 *    Due to Prisma's CASCADE definitions, this also purges all nested user data.
 * 2. Archived QuickTasks (archivedAt is set and older than 30 days).
 */
export const runDatabaseCleanup = async () => {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  console.log(`[Database Cleanup] Starting pruning routine. Target threshold: ${thirtyDaysAgo.toISOString()}`);

  try {
    // 1. Purge soft-deleted users (older than 30 days)
    const deletedUsers = await prisma.user.deleteMany({
      where: {
        deletedAt: {
          lte: thirtyDaysAgo,
        },
      },
    });

    // 2. Purge archived tasks (older than 30 days)
    const deletedTasks = await prisma.quickTask.deleteMany({
      where: {
        status: 'archived',
        archivedAt: {
          lte: thirtyDaysAgo,
        },
      },
    });

    console.log(
      `[Database Cleanup] Completed. Purged ${deletedUsers.count} users and ${deletedTasks.count} archived tasks.`
    );
  } catch (error) {
    console.error('[Database Cleanup] Error running database cleanup:', error);
  }
};

/**
 * Initializes the background pruning job on server startup.
 * Runs once immediately on boot, then repeats every 24 hours.
 */
export const startCleanupJob = () => {
  // Run once immediately on boot
  runDatabaseCleanup();

  // Set interval to run every 24 hours
  const TWENTY_FOUR_HOURS = 24 * 60 * 60 * 1000;
  setInterval(runDatabaseCleanup, TWENTY_FOUR_HOURS);
  
  console.log('[Database Cleanup] Scheduled daily cleanup worker.');
};
