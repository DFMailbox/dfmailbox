# DFMailbox
A decentralized way to pass messages to other DiamondFire plots

# Deployment
The project uses docker so ensure that is installed
1. Clone the repo
```sh
git clone https://github.com/DynamicCake/dfmailbox
cd dfmailbox
```
2. Run the make file, this will prompt you to create the .env file
```sh
make
```

# Testing
This project runs unit and compliance tests.
- Unit tests are ran in GitHub's ci-cd pipeline but can also be tested with `gleam test`
- Compliance tests can be ran with `make compliance_test`

# Development
1. Run `make`
2. Edit generated `.env` to add
```sh
...
TARGET=dev
```
3. Install gleam and erlang. `nix develop` if you have the nix package manager
4. Run `docker compose up --build` and press `w` to watch for changes
    - or `make` if you are feeling like it

## Windows
Install [git bash](https://gitforwindows.org/) and [make for windows](https://gnuwin32.sourceforge.net/packages/make.htm), then follow the steps.

