#! /usr/bin/env bash

# https://www.baeldung.com/linux/store-command-in-variable
readonly TERRAFORM_CMD=("terraform" "-chdir=${TERRAFORM_TEMPLATE_DIR}")
readonly TERRAFORM_APPLY=(${TERRAFORM_CMD[@]} "apply" "-input=false")

#######################################
# Destorys the terraform code
# Globals:
#   TERRAFORM_PLAN_OUT_FILE
#   TF_VAR_FILENAME
#######################################
function terraform::perform_destory() {
  "${TERRAFORM_CMD[@]}" plan \
    -input=false \
    -out="${TERRAFORM_PLAN_OUT_FILE}" \
    -var-file="${TF_VAR_FILENAME}"
  -destroy

  if civiform_mode::is_test; then
    return 0
  fi

  # We are not using plan generated in the previous step,
  # because that will never ask for confirmation.
  if azure::is_service_principal; then
    "${TERRAFORM_APPLY[@]}" -auto-approve
  else
    "${TERRAFORM_APPLY[@]}"
  fi
}

#######################################
# Generates terraform variable files and runs terraform init and apply.
# Also initializes the storage bucket for tfstate if it's not setup yet.
# Globals:
#   TERRAFORM_TEMPLATE_DIR
#   BACKEND_VARS_FILENAME
#   TF_VAR_FILENAME
#######################################
function terraform::perform_apply() {
  if civiform_mode::use_local_backend; then
    "${TERRAFORM_CMD[@]}" init -upgrade
  else
    "cloud/${CIVIFORM_CLOUD_PROVIDER}/bin/setup_tf_shared_state" \
      "${TERRAFORM_TEMPLATE_DIR}/${BACKEND_VARS_FILENAME}"

    "${TERRAFORM_CMD[@]}" \
      init \
      -input=false \
      -upgrade \
      -backend-config="${BACKEND_VARS_FILENAME}"
  fi

  if [[ -f "${TERRAFORM_TEMPLATE_DIR}/${TF_VAR_FILENAME}" ]]; then
    echo "${TF_VAR_FILENAME} exists in ${TERRAFORM_TEMPLATE_DIR} directory"
  else
    echo "Cannot find ${TF_VAR_FILENAME} in ${TERRAFORM_TEMPLATE_DIR} directory"
    exit 1
  fi

  "${TERRAFORM_CMD[@]}" plan \
    -input=false \
    -out="${TERRAFORM_PLAN_OUT_FILE}" \
    -var-file="${TF_VAR_FILENAME}"

  if civiform_mode::is_test; then
    return 0
  fi

  # We are not using plan generated in the previous step,
  # because that will never ask for confirmation.
  if civiform_mode::skip_confirmations; then
    "${TERRAFORM_APPLY[@]}" -auto-approve
  else
    "${TERRAFORM_APPLY[@]}"
  fi
}

#######################################
# Copies the terraform backend_override to backend_override.tf (used to
# make backend local instead of a shared state for dev deploys)
# Globals:
#   TERRAFORM_TEMPLATE_DIR
#######################################
function terraform::copy_override() {
  cp "${TERRAFORM_TEMPLATE_DIR}/backend_override" \
    "${TERRAFORM_TEMPLATE_DIR}/backend_override.tf"
}
