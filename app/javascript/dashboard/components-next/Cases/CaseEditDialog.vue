<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import CasesAPI from 'dashboard/api/cases';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const emit = defineEmits(['updated']);

// Edit case: the subject, severity and team an agent can correct after the case opened itself.
// Status and owner stay the conversation's, so they are not here.
const SEVERITIES = ['p1', 'p2', 'p3', 'p4'];
const SUBJECT_LENGTH = 255;

const { t } = useI18n();
const teams = useMapGetter('teams/getTeams');

const dialogRef = ref(null);
const caseId = ref(null);
const display = ref('');
const subject = ref('');
const severity = ref('p4');
const teamId = ref('');
const isFetching = ref(false);
const isSaving = ref(false);

const severityOptions = computed(() =>
  SEVERITIES.map(value => ({ value, label: t(`CASES.SEVERITY.${value}`) }))
);
const teamOptions = computed(() => [
  { value: '', label: t('CASES.NO_TEAM') },
  ...teams.value.map(team => ({ value: team.id, label: team.name })),
]);
const canSave = computed(
  () => !isFetching.value && !isSaving.value && subject.value.trim() !== ''
);

const open = async id => {
  caseId.value = id;
  subject.value = '';
  isFetching.value = true;
  dialogRef.value?.open();
  try {
    const { data } = await CasesAPI.show(id);
    display.value = data.display;
    subject.value = data.subject;
    severity.value = data.severity;
    teamId.value = data.team?.id ?? '';
  } catch (error) {
    useAlert(t('CASES.EDIT.FETCH_ERROR'));
    dialogRef.value?.close();
  } finally {
    isFetching.value = false;
  }
};

const close = () => dialogRef.value?.close();

defineExpose({ open, close });

const save = async () => {
  if (!canSave.value) return;

  isSaving.value = true;
  try {
    await CasesAPI.update(caseId.value, {
      subject: subject.value.trim().slice(0, SUBJECT_LENGTH),
      severity: severity.value,
      team_id: teamId.value || null,
    });
    useAlert(t('CASES.EDIT.SUCCESS'));
    emit('updated');
    close();
  } catch (error) {
    useAlert(t('CASES.EDIT.ERROR'));
  } finally {
    isSaving.value = false;
  }
};
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="lg"
    :title="t('CASES.EDIT.TITLE', { display })"
    :description="t('CASES.EDIT.DESCRIPTION')"
    :confirm-button-label="t('CASES.EDIT.SAVE')"
    :cancel-button-label="t('CASES.EDIT.CANCEL')"
    :disable-confirm-button="!canSave"
    :is-loading="isSaving"
    @confirm="save"
  >
    <div v-if="isFetching" class="flex justify-center py-6">
      <Spinner />
    </div>
    <div v-else class="flex flex-col gap-4">
      <Input
        v-model="subject"
        :label="t('CASES.TABLE.SUBJECT')"
        autofocus
        @enter="save"
      />
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('CASES.TABLE.SEVERITY') }}
        </span>
        <Select
          v-model="severity"
          :options="severityOptions"
          :aria-label="t('CASES.TABLE.SEVERITY')"
        />
      </div>
      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('CASES.TABLE.TEAM') }}
        </span>
        <Select
          v-model="teamId"
          :options="teamOptions"
          :aria-label="t('CASES.TABLE.TEAM')"
        />
      </div>
    </div>
  </Dialog>
</template>
