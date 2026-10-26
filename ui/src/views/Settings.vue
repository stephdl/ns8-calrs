<!--
  Copyright (C) 2026 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <cv-text-input
              :label="$t('settings.calrs_fqdn')"
              placeholder="calrs.example.org"
              v-model.trim="host"
              class="mg-bottom"
              :invalid-message="$t(error.host)"
              :disabled="loading.getConfiguration || loading.configureModule"
              ref="host"
            >
            </cv-text-input>
            <NsToggle
              value="letsEncrypt"
              :label="core.$t('apps_lets_encrypt.request_https_certificate')"
              v-model="isLetsEncryptEnabled"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template #tooltip>
                <div class="mg-bottom-sm">
                  {{ core.$t("apps_lets_encrypt.lets_encrypt_tips") }}
                </div>
                <div class="mg-bottom-sm">
                  <cv-link @click="goToCertificates">
                    {{ core.$t("apps_lets_encrypt.go_to_tls_certificates") }}
                  </cv-link>
                </div>
              </template>
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <cv-row
              v-if="isLetsEncryptCurrentlyEnabled && !isLetsEncryptEnabled"
            >
              <cv-column>
                <NsInlineNotification
                  kind="warning"
                  :title="
                    core.$t('apps_lets_encrypt.lets_encrypt_disabled_warning')
                  "
                  :description="
                    core.$t(
                      'apps_lets_encrypt.lets_encrypt_disabled_warning_description',
                      {
                        node: this.status.node_ui_name
                          ? this.status.node_ui_name
                          : this.status.node,
                      }
                    )
                  "
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <h4 class="mg-bottom">{{ $t("settings.admin_account") }}</h4>
            <NsInlineNotification
              kind="info"
              :title="$t('settings.admin_account')"
              :description="
                isAdminConfigured
                  ? $t('settings.admin_account_info_set', {
                      email: adminEmail,
                    })
                  : $t('settings.admin_account_info')
              "
              :showCloseButton="false"
              class="mg-bottom maxwidth"
            />
            <NsToggle
              v-if="isAdminConfigured"
              key="changeAdminPassword"
              value="changeAdminPassword"
              :label="$t('settings.change_admin_password')"
              v-model="isChangePassword"
              :disabled="stillLoading"
              class="mg-bottom"
            >
              <template slot="text-left">{{
                $t("settings.disabled")
              }}</template>
              <template slot="text-right">{{
                $t("settings.enabled")
              }}</template>
            </NsToggle>
            <template v-if="!isAdminConfigured">
              <cv-text-input
                :label="$t('settings.admin_email')"
                placeholder="admin@example.org"
                v-model.trim="adminEmail"
                class="mg-bottom"
                :invalid-message="$t(error.admin_email)"
                :disabled="stillLoading"
                ref="admin_email"
              >
              </cv-text-input>
              <cv-text-input
                :label="$t('settings.admin_name')"
                v-model.trim="adminName"
                class="mg-bottom"
                :invalid-message="$t(error.admin_name)"
                :disabled="stillLoading"
                ref="admin_name"
              >
              </cv-text-input>
            </template>
            <NsPasswordInput
              v-if="isPasswordActive"
              key="adminPassword"
              v-model="adminPassword"
              :newPasswordLabel="$t('settings.admin_password')"
              :confirmPasswordLabel="$t('settings.admin_password_confirm')"
              :newPasswordInvalidMessage="$t(error.admin_password)"
              :confirmPasswordInvalidMessage="$t(error.admin_password_confirm)"
              :passwordHideLabel="core.$t('password.hide_password')"
              :passwordShowLabel="core.$t('password.show_password')"
              :lengthLabel="core.$t('password.long_enough')"
              :lowercaseLabel="core.$t('password.lowercase_letter')"
              :uppercaseLabel="core.$t('password.uppercase_letter')"
              :numberLabel="core.$t('password.number')"
              :symbolLabel="core.$t('password.symbol')"
              :equalLabel="core.$t('password.equal')"
              :focus="focusPasswordField"
              :minLength="12"
              :disabled="stillLoading"
              @passwordValidation="onAdminPasswordValidation"
              class="mg-bottom maxwidth"
            />
            <!-- advanced options -->
            <cv-accordion ref="accordion" class="maxwidth mg-bottom">
              <cv-accordion-item :open="isAdvancedOpen">
                <template slot="title">{{ $t("settings.advanced") }}</template>
                <template slot="content">
                  <NsTextInput
                    :label="$t('settings.mail_from')"
                    placeholder="noreply@calrs.example.org"
                    v-model.trim="mailFrom"
                    :helper-text="$t('settings.mail_from_helper')"
                    :invalid-message="$t(error.mail_from)"
                    :disabled="stillLoading"
                    class="mg-bottom"
                    ref="mail_from"
                  ></NsTextInput>
                  <NsInlineNotification
                    kind="info"
                    :title="$t('settings.allow_private_hosts')"
                    :description="$t('settings.allow_private_hosts_info')"
                    :showCloseButton="false"
                    class="mg-bottom"
                  />
                  <NsTextInput
                    :label="$t('settings.allow_private_hosts')"
                    v-model.trim="allowPrivateHosts"
                    :helper-text="$t('settings.allow_private_hosts_helper')"
                    :invalid-message="$t(error.allow_private_hosts)"
                    :disabled="stillLoading"
                    ref="allow_private_hosts"
                  ></NsTextInput>
                </template>
              </cv-accordion-item>
            </cv-accordion>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-row v-if="error.getStatus">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.get-status')"
                  :description="error.getStatus"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <cv-row v-if="validationErrorDetails.length">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="
                    core.$t('apps_lets_encrypt.cannot_obtain_certificate')
                  "
                  :showCloseButton="false"
                >
                  <template #description>
                    <div class="flex flex-col gap-2">
                      <div
                        v-for="(detail, index) in validationErrorDetails"
                        :key="index"
                      >
                        {{ detail }}
                      </div>
                    </div>
                  </template>
                </NsInlineNotification>
              </cv-column>
            </cv-row>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

// Fields living inside the collapsed advanced accordion: a validation error on
// one of them must open it, otherwise the message is reported on a hidden input
const ADVANCED_FIELDS = ["mail_from", "allow_private_hosts"];

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      status: {},
      validationErrorDetails: [],
      urlCheckInterval: null,
      host: "",
      mailFrom: "",
      allowPrivateHosts: "",
      adminEmail: "",
      adminName: "",
      adminPassword: "",
      adminPasswordValidation: null,
      focusPasswordField: { element: "" },
      isAdminConfigured: false,
      isChangePassword: false,
      isAdvancedOpen: false,
      isLetsEncryptEnabled: false,
      isLetsEncryptCurrentlyEnabled: false,
      loading: {
        getConfiguration: false,
        configureModule: false,
        getStatus: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        host: "",
        lets_encrypt: "",
        mail_from: "",
        allow_private_hosts: "",
        admin_email: "",
        admin_name: "",
        admin_password: "",
        admin_password_confirm: "",
        getStatus: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    stillLoading() {
      return (
        this.loading.getConfiguration ||
        this.loading.configureModule ||
        this.loading.getStatus
      );
    },
    isPasswordActive() {
      // before the configuration loads every instance looks unconfigured
      if (this.loading.getConfiguration) {
        return false;
      }
      return !this.isAdminConfigured || this.isChangePassword;
    },
  },
  watch: {
    adminPassword() {
      this.error.admin_password = "";
      this.error.admin_password_confirm = "";
    },
    isChangePassword() {
      this.adminPassword = "";
      this.error.admin_password = "";
      this.error.admin_password_confirm = "";
    },
  },
  created() {
    this.getConfiguration();
    this.getStatus();
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  methods: {
    goToCertificates() {
      this.core.$router.push("/settings/tls-certificates");
    },
    onAdminPasswordValidation(validation) {
      this.adminPasswordValidation = validation;
    },
    async getStatus() {
      this.loading.getStatus = true;
      this.error.getStatus = "";
      const taskAction = "get-status";
      const eventId = this.getUuid();
      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getStatusAborted
      );
      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getStatusCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getStatus = this.getErrorMessage(err);
        this.loading.getStatus = false;
        return;
      }
    },
    getStatusAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getStatus = this.$t("error.generic_error");
      this.loading.getStatus = false;
    },
    getStatusCompleted(taskContext, taskResult) {
      this.status = taskResult.output;
      this.loading.getStatus = false;
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.host = config.host;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isLetsEncryptCurrentlyEnabled = config.lets_encrypt;
      this.mailFrom = config.mail_from;
      this.allowPrivateHosts = config.allow_private_hosts.join(", ");
      this.adminEmail = config.admin_email;
      this.isAdminConfigured = !!config.admin_email;
      this.isChangePassword = false;

      this.loading.getConfiguration = false;
      this.focusElement("host");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      this.validationErrorDetails = [];
      let isValidationOk = true;
      if (!this.host) {
        this.error.host = "common.required";

        if (isValidationOk) {
          this.focusElement("host");
        }
        isValidationOk = false;
      }

      // Skipping the account would publish the instance with open registration,
      // and calrs promotes the first account that registers to administrator
      if (!this.isAdminConfigured) {
        if (!this.adminEmail) {
          this.error.admin_email = "common.required";
          if (isValidationOk) {
            this.focusElement("admin_email");
          }
          isValidationOk = false;
        }

        if (!this.adminName) {
          this.error.admin_name = "common.required";
          if (isValidationOk) {
            this.focusElement("admin_name");
          }
          isValidationOk = false;
        }
      }

      if (this.isPasswordActive) {
        const v = this.adminPasswordValidation;
        const isStrong =
          v &&
          v.isLengthOk &&
          v.isLowercaseOk &&
          v.isUppercaseOk &&
          v.isNumberOk &&
          v.isSymbolOk;
        if (!isStrong) {
          this.error.admin_password = "settings.admin_password_too_weak";
          if (isValidationOk) {
            this.focusPasswordField = { element: "newPassword" };
          }
          isValidationOk = false;
        } else if (!v.isEqualOk) {
          this.error.admin_password_confirm =
            "settings.admin_password_mismatch";
          if (isValidationOk) {
            this.focusPasswordField = { element: "confirmPassword" };
          }
          isValidationOk = false;
        }
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusParam = "";
      let openAdvanced = false;
      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        if (validationError.details) {
          // show inline error notification with details
          this.validationErrorDetails = validationError.details
            .split("\n")
            .filter((detail) => detail.trim() !== "");
        } else {
          // set i18n error message
          this.error[param] = this.$t("settings." + validationError.error);
          openAdvanced = openAdvanced || ADVANCED_FIELDS.includes(param);
          focusParam = focusParam || param;
        }
      }

      // cv-accordion-item copies the open prop into its own state and a manual
      // collapse leaves the two apart, so re-asserting true changes nothing:
      // drive the prop through false to make the watcher fire
      if (openAdvanced) {
        this.isAdvancedOpen = false;
      }
      if (focusParam) {
        this.$nextTick(() => {
          if (openAdvanced) {
            this.isAdvancedOpen = true;
          }
          this.$nextTick(() => {
            if (focusParam === "admin_password") {
              this.focusPasswordField = { element: "newPassword" };
            } else {
              this.focusElement(focusParam);
            }
          });
        });
      }
    },
    async configureModule() {
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            host: this.host,
            lets_encrypt: this.isLetsEncryptEnabled,
            mail_from: this.mailFrom,
            allow_private_hosts: this.allowPrivateHosts
              ? this.allowPrivateHosts
                  .split(",")
                  .map((host) => host.trim())
                  .filter((host) => host)
              : [],
            ...(this.isAdminConfigured
              ? {}
              : {
                  admin_email: this.adminEmail,
                  admin_name: this.adminName,
                }),
            ...(this.isPasswordActive
              ? { admin_password: this.adminPassword }
              : {}),
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;
      this.adminPassword = "";

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}

.maxwidth {
  max-width: 38rem;
}
</style>
