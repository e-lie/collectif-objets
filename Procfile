web: RAILS_MAX_THREADS=5 bundle exec puma -C config/puma.rb
worker: GOOD_JOB_MAX_THREADS=5 bundle exec good_job start
postdeploy: ./scripts/postdeploy.sh
