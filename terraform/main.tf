module "fourkeys" {
  source     = "./modules/fourkeys"
  project_id = var.project_id
  region     = var.region
}