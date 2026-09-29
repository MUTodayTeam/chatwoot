import { computed, onMounted, unref } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';

/**
 * The project an inbox belongs to, or null.
 *
 * The project is read from the projects list rather than from the inbox payload:
 * inboxes are served from an IndexedDB cache that only refreshes when an inbox
 * changes, so a freshly added field can be missing there for a while.
 * @param {import('vue').Ref<number>|number} inboxId
 */
export const useInboxProject = inboxId => {
  const store = useStore();
  const projects = useMapGetter('projects/getProjects');

  onMounted(() => {
    if (!projects.value.length) store.dispatch('projects/get');
  });

  return computed(
    () =>
      projects.value.find(project =>
        project.inboxIds?.includes(unref(inboxId))
      ) ?? null
  );
};
