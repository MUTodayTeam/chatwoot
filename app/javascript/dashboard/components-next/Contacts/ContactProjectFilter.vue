<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

// Narrows the contacts list to people with a conversation in one project
const props = defineProps({
  modelValue: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const projects = useMapGetter('projects/getProjects');
const [showMenu, toggleMenu] = useToggle();

const menuItems = computed(() => [
  { label: t('CONTACT_360.PROJECT_FILTER.ALL'), value: null },
  ...projects.value.map(project => ({
    label: project.name,
    value: project.id,
  })),
]);

const selectedLabel = computed(
  () =>
    menuItems.value.find(item => item.value === props.modelValue)?.label ||
    menuItems.value[0].label
);

const selectProject = ({ value }) => {
  toggleMenu(false);
  if (value !== props.modelValue) emit('update:modelValue', value);
};
</script>

<template>
  <div
    v-on-clickaway="() => toggleMenu(false)"
    class="relative flex items-center w-fit"
  >
    <Button
      sm
      slate
      faded
      icon="i-lucide-folder"
      :label="selectedLabel"
      @click="toggleMenu()"
    />
    <DropdownMenu
      v-if="showMenu"
      :menu-items="menuItems"
      class="z-50 mt-1 start-0 top-full"
      @action="selectProject"
    />
  </div>
</template>
