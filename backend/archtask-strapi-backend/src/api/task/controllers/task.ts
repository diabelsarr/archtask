import { factories } from '@strapi/strapi';

/**
 * Personnalisation du contrôleur Task, en contournant les actions par
 * défaut pour éviter les restrictions de population sur la relation
 * "user" et les soucis de syntaxe de filtre.
 */
export default factories.createCoreController(
  'api::task.task',
  ({ strapi }: { strapi: any }) => ({
    async find(ctx: any) {
      const currentUserId = ctx.state.user.id;
      const tasks = await strapi.documents('api::task.task').findMany({
        filters: { user: currentUserId },
        populate: { user: { fields: ['id', 'username'] } },
      });
      return {
        data: tasks,
        meta: {
          pagination: {
            page: 1,
            pageSize: tasks.length,
            pageCount: 1,
            total: tasks.length,
          },
        },
      };
    },

    async findOne(ctx: any) {
      const { id } = ctx.params;
      const task: any = await strapi.documents('api::task.task').findOne({
        documentId: id,
        populate: { user: { fields: ['id', 'username'] } },
      });
      if (!task || task.user?.id !== ctx.state.user.id) {
        return ctx.forbidden('Accès refusé à cette tâche.');
      }
      return { data: task, meta: {} };
    },

    async create(ctx: any) {
      const currentUserId = ctx.state.user.id;
      const task = await strapi.documents('api::task.task').create({
        data: { ...ctx.request.body.data, user: currentUserId },
        status: 'published',
      });
      return { data: task, meta: {} };
    },

    async update(ctx: any) {
      const { id } = ctx.params;
      const task: any = await strapi.documents('api::task.task').findOne({
        documentId: id,
        populate: ['user'],
      });
      if (!task || task.user?.id !== ctx.state.user.id) {
        return ctx.forbidden('Accès refusé à cette tâche.');
      }
      const updated = await strapi.documents('api::task.task').update({
        documentId: id,
        data: ctx.request.body.data,
        status: 'published',
      });
      return { data: updated, meta: {} };
    },

    async delete(ctx: any) {
      const { id } = ctx.params;
      const task: any = await strapi.documents('api::task.task').findOne({
        documentId: id,
        populate: ['user'],
      });
      if (!task || task.user?.id !== ctx.state.user.id) {
        return ctx.forbidden('Accès refusé à cette tâche.');
      }
      const deleted = await strapi.documents('api::task.task').delete({
        documentId: id,
      });
      return { data: deleted, meta: {} };
    },
  })
);
