# DFQueue
A decentralized way to pass messages to other DiamondFire plots

# Deployment
To deploy this, follow these steps
1. Run `./gen_env.sh` to generate a .env file
2. Run `docker compose up --build` to run the server

If you have another PostgreSQL or Redis instance, edit the `docker-compose.yml` file to suit your needs

# Development
1. Run `./gen_env.sh`
2. Edit generated `.env`'s `TARGET` to be `dev` instead of `prod` for faster runs
3. Run `docker compose watch` to watch for changes

