# macforge-requires: terraform
# vim: ft=sh sw=2 ts=2 expandtab

alias tf="terraform"
alias tfi="terraform init"
alias tfv="terraform validate"
alias tfp="terraform plan"
alias tfpo="terraform plan -out base-`date +'%s'`.plan"
alias tfa="terraform apply"
alias tfo="terraform output"
alias tfd="terraform destroy"
alias tfs="terraform show"
alias tfwl="terraform workspace list"
alias tfws="terraform workspace select"
alias tfnw="terraform workspace new"
alias tffc="terraform fmt -recursive -check"
alias tffw="terraform fmt -recursive -write=true"
alias tfg="terraform graph > base.dot && dot base.dot -Tsvg -o base.svg && open base.svg"
