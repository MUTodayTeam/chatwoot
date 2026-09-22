<script>
/* eslint no-console: 0 */
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

import InboxMembersAPI from '../../../../api/inboxMembers';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import router from '../../../index';
import PageHeader from '../SettingsSubPageHeader.vue';
import { useVuelidate } from '@vuelidate/core';

export default {
  components: {
    PageHeader,
    NextButton,
    TagInput,
  },
  validations: {
    selectedAgentIds: {
      isEmpty() {
        return !!this.selectedAgentIds.length;
      },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      selectedAgentIds: [],
      selectedProjectId: '',
      hasSeededAgents: false,
      isCreating: false,
    };
  },
  computed: {
    ...mapGetters({
      agentList: 'agents/getAgents',
      projects: 'projects/getProjects',
    }),
    areAllAgentsSelected() {
      return (
        !!this.agentList.length &&
        this.selectedAgentIds.length === this.agentList.length
      );
    },
    selectedAgentNames() {
      return this.selectedAgentIds.map(
        id => this.agentList.find(a => a.id === id)?.name ?? ''
      );
    },
    agentMenuItems() {
      return this.agentList
        .filter(({ id }) => !this.selectedAgentIds.includes(id))
        .map(({ id, name, thumbnail, avatar_url }) => ({
          label: name,
          value: id,
          action: 'select',
          thumbnail: { name, src: thumbnail || avatar_url || '' },
        }));
    },
  },
  watch: {
    // The agent list arrives after mount. Seed the selection with everyone the
    // first time it lands: an inbox with no agents is invisible to the team, and
    // narrowing it afterwards is one click.
    agentList: {
      immediate: true,
      handler(agents) {
        if (this.hasSeededAgents || !agents.length) return;
        this.hasSeededAgents = true;
        this.selectedAgentIds = agents.map(({ id }) => id);
      },
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('projects/get');
  },
  methods: {
    handleAgentAdd({ value }) {
      if (!this.selectedAgentIds.includes(value)) {
        this.selectedAgentIds.push(value);
      }
    },
    handleAgentRemove(index) {
      this.selectedAgentIds.splice(index, 1);
    },
    selectAllAgents() {
      this.selectedAgentIds = this.agentList.map(({ id }) => id);
    },
    clearAgents() {
      this.selectedAgentIds = [];
    },
    async addAgents() {
      this.isCreating = true;
      const inboxId = this.$route.params.inbox_id;

      try {
        await InboxMembersAPI.update({
          inboxId,
          agentList: this.selectedAgentIds,
        });
        if (this.selectedProjectId) {
          await this.$store.dispatch('inboxes/updateInbox', {
            id: inboxId,
            formData: false,
            project_id: this.selectedProjectId,
          });
        }
        router.replace({
          name: 'settings_inbox_finish',
          params: {
            page: 'new',
            inbox_id: this.$route.params.inbox_id,
          },
        });
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="addAgents()">
      <div class="w-full">
        <PageHeader
          :header-title="$t('INBOX_MGMT.ADD.AGENTS.TITLE')"
          :header-content="$t('INBOX_MGMT.ADD.AGENTS.DESC')"
        />
      </div>
      <div>
        <div class="w-full mb-4">
          <label :class="{ error: v$.selectedAgentIds.$error }">
            {{ $t('INBOX_MGMT.ADD.AGENTS.TITLE') }}
            <div
              data-testid="agent-selector"
              class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong px-2 py-2"
            >
              <TagInput
                :model-value="selectedAgentNames"
                :placeholder="$t('INBOX_MGMT.ADD.AGENTS.PICK_AGENTS')"
                :menu-items="agentMenuItems"
                show-dropdown
                skip-label-dedup
                @add="handleAgentAdd"
                @remove="handleAgentRemove"
              />
            </div>
            <span v-if="v$.selectedAgentIds.$error" class="message">
              {{ $t('INBOX_MGMT.ADD.AGENTS.VALIDATION_ERROR') }}
            </span>
          </label>
          <div class="flex gap-3 mt-2">
            <button
              type="button"
              class="p-0 text-sm font-medium bg-transparent border-0 text-n-blue-text hover:underline disabled:opacity-50 disabled:no-underline"
              :disabled="areAllAgentsSelected"
              @click="selectAllAgents"
            >
              {{ $t('INBOX_MGMT.ADD.AGENTS.SELECT_ALL') }}
            </button>
            <button
              type="button"
              class="p-0 text-sm font-medium bg-transparent border-0 text-n-slate-11 hover:underline disabled:opacity-50 disabled:no-underline"
              :disabled="!selectedAgentIds.length"
              @click="clearAgents"
            >
              {{ $t('INBOX_MGMT.ADD.AGENTS.CLEAR_ALL') }}
            </button>
          </div>
        </div>
        <div v-if="projects.length" class="w-full mb-4">
          <label for="inbox-project">
            {{ $t('INBOX_MGMT.ADD.PROJECT.TITLE') }}
            <select id="inbox-project" v-model="selectedProjectId">
              <option value="">
                {{ $t('INBOX_MGMT.ADD.PROJECT.NONE') }}
              </option>
              <option
                v-for="project in projects"
                :key="project.id"
                :value="project.id"
              >
                {{ project.name }}
              </option>
            </select>
          </label>
          <p class="mt-0 text-sm text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.PROJECT.DESC') }}
          </p>
        </div>
        <div class="w-full">
          <NextButton
            type="submit"
            :is-loading="isCreating"
            solid
            blue
            :label="$t('INBOX_MGMT.AGENTS.BUTTON_TEXT')"
          />
        </div>
      </div>
    </form>
  </div>
</template>
