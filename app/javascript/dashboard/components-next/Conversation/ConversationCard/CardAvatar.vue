<script setup>
import { ref, computed } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import CardChannelBadge from './CardChannelBadge.vue';

const props = defineProps({
  contact: { type: Object, required: true },
  selected: { type: Boolean, default: false },
  enableSelection: { type: Boolean, default: true },
  hideThumbnail: { type: Boolean, default: false },
  chat: { type: Object, default: null },
});

const emit = defineEmits(['selectConversation']);

const hovered = ref(false);

const onThumbnailHover = () => {
  hovered.value = !props.hideThumbnail;
};

const onThumbnailLeave = () => {
  hovered.value = false;
};

const selectedModel = computed({
  get: () => props.selected,
  set: value => {
    emit('selectConversation', value);
  },
});
</script>

<template>
  <div
    class="relative flex items-center flex-shrink-0"
    @mouseenter="onThumbnailHover"
    @mouseleave="onThumbnailLeave"
  >
    <div v-if="!hideThumbnail" class="relative w-fit">
      <Avatar
        :name="contact.name"
        :src="contact.thumbnail"
        :size="24"
        :status="contact.availability_status"
        hide-offline-status
      >
        <template v-if="enableSelection" #overlay>
          <div
            v-if="hovered || selected"
            class="flex items-center justify-center rounded-md cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px] size-6"
            @click.stop
          >
            <Checkbox v-model="selectedModel" />
          </div>
        </template>
      </Avatar>
      <CardChannelBadge
        v-if="chat"
        :chat="chat"
        class="absolute -bottom-1.5 -end-1.5 z-20"
      />
    </div>
  </div>
</template>
