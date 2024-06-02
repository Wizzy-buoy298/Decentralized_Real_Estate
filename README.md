# Decentralized Real Estate Platform

## Overview

The decentralized_real_estate::real_estate module on the Sui blockchain platform is designed to facilitate the buying, selling, and renting of real estate properties through a decentralized network. This module allows users to create property listings, initiate and verify transactions, manage rental agreements, and handle payments efficiently.

## Table of Contents

- [Decentralized Real Estate Platform](#decentralized-real-estate-platform)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Prerequisites](#prerequisites-1)
  - [Installation](#installation-1)
  - [Run a local network](#run-a-local-network)
  - [Configure connectivity to a local node](#configure-connectivity-to-a-local-node)
    - [Create addresses](#create-addresses)
    - [Get localnet SUI tokens](#get-localnet-sui-tokens)
  - [Build and publish a smart contract](#build-and-publish-a-smart-contract)
    - [Build package](#build-package)
    - [Publish package](#publish-package)
  - [Structs](#structs)
    - [Property](#property)
    - [Transaction](#transaction)
    - [RentalAgreement](#rentalagreement)
  - [Functions](#functions)
    - [create\_property](#create_property)
    - [list\_property\_for\_sale](#list_property_for_sale)
    - [delist\_property\_from\_sale](#delist_property_from_sale)
    - [create\_transaction](#create_transaction)
    - [verify\_transaction](#verify_transaction)
    - [complete\_transaction](#complete_transaction)
    - [create\_rental\_agreement](#create_rental_agreement)
    - [pay\_rent](#pay_rent)
    - [end\_rental\_agreement](#end_rental_agreement)
## Prerequisites

1. Install dependencies:

   - `sudo apt update`
   - `sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y`

2. Install Rust and Cargo:

   - `curl https://sh.rustup.rs -sSf | sh`
   - `source "$HOME/.cargo/env"`

3. Install Sui Binaries:
   - Make the file executable: `chmod u+x sui-binaries.sh`
   - Execute the installation file:
     - Debian/Ubuntu: `./sui-binaries.sh "v1.21.0" "devnet" "ubuntu-x86_64"`
     - Mac OS (Intel): `./sui-binaries.sh "v1.21.0" "devnet" "macos-x86_64"`
     - Mac OS (Silicon): `./sui-binaries.sh "v1.21.0" "devnet" "macos-arm64"`

## Installation

1. Clone the repository:
   ```sh
   git clone
   ```

## Prerequisites

1. Install dependencies by running the following commands:

   - `sudo apt update`

   - `sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y`

2. Install Rust and Cargo

   - `curl https://sh.rustup.rs -sSf | sh`

   - source "$HOME/.cargo/env"

3. Install Sui Binaries

   - run the command `chmod u+x sui-binaries.sh` to make the file an executable

   execute the installation file by running

   - `./sui-binaries.sh "v1.21.0" "devnet" "ubuntu-x86_64"` for Debian/Ubuntu Linux users

   - `./sui-binaries.sh "v1.21.0" "devnet" "macos-x86_64"` for Mac OS users with Intel based CPUs

   - `./sui-binaries.sh "v1.21.0" "devnet" "macos-arm64"` for Silicon based Mac

For detailed installation instructions, refer to the [Installation and Deployment](#installation-and-deployment) section in the provided documentation.

## Installation

1. Clone the repo
   ```sh
   git clone 
   ```
2. Navigate to the working directory
   ```sh
   cd 
   ```

## Run a local network

To run a local network with a pre-built binary (recommended way), run this command:

```
RUST_LOG="off,sui_node=info" sui-test-validator
```

## Configure connectivity to a local node

Once the local node is running (using `sui-test-validator`), you should the url of a local node - `http://127.0.0.1:9000` (or similar).
Also, another url in the output is the url of a local faucet - `http://127.0.0.1:9123`.

Next, we need to configure a local node. To initiate the configuration process, run this command in the terminal:

```
sui client active-address
```

The prompt should tell you that there is no configuration found:

```
Config file ["/home/codespace/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```

Type `y` and in the following prompts provide a full node url `http://127.0.0.1:9000` and a name for the config, for example, `localnet`.

On the last prompt you will be asked which key scheme to use, just pick the first one (`0` for `ed25519`).

After this, you should see the ouput with the wallet address and a mnemonic phrase to recover this wallet. You can save so later you can import this wallet into SUI Wallet.

Additionally, you can create more addresses and to do so, follow the next section - `Create addresses`.

### Create addresses

For this tutorial we need two separate addresses. To create an address run this command in the terminal:

```
sui client new-address ed25519
```

where:

- `ed25519` is the key scheme (other available options are: `ed25519`, `secp256k1`, `secp256r1`)

And the output should be similar to this:

```
╭─────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.                                                   │
├────────────────┬────────────────────────────────────────────────────────────────────────────────┤
│ address        │ 0x05db1e318f1e4bc19eb3f2fa407b3ebe1e7c3cd8147665aacf2595201f731519             │
│ keyScheme      │ ed25519                                                                        │
│ recoveryPhrase │ lava perfect chef million beef mean drama guide achieve garden umbrella second │
╰────────────────┴────────────────────────────────────────────────────────────────────────────────╯
```

Use `recoveryPhrase` words to import the address to the wallet app.

### Get localnet SUI tokens

```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```

`<ADDRESS>` - replace this by the output of this command that returns the active address:

```
sui client active-address
```

You can switch to another address by running this command:

```
sui client switch --address <ADDRESS>
```

## Build and publish a smart contract

### Build package

To build tha package, you should run this command:

```
sui move build
```

If the package is built successfully, the next step is to publish the package:

### Publish package

```
sui client publish --gas-budget 100000000 --json
` - `sui client publish --gas-budget 1000000000`
```

## Structs

### Property

```
struct Property has key, store {
    id: UID,
    owner: address,
    location: vector<u8>,
    size: u64,
    price: u64,
    balance: Balance<SUI>,
    is_for_sale: bool,
    documents: vector<u8>,
}

```

### Transaction

```
struct Transaction has key, store {
    id: UID,
    property_id: u64,
    buyer: address,
    seller: address,
    amount: u64,
    verifiers: vector<address>,
    is_verified: bool,
    is_completed: bool,
}


```

### RentalAgreement

```
struct RentalAgreement has key, store {
    id: UID,
    property_id: u64,
    tenant: address,
    owner: address,
    rent_amount: u64,
    due_date: u64,
    is_active: bool,
}

```

## Functions

### create_property
- Creates a new property listing.

### list_property_for_sale
- Lists a property for sale.

### delist_property_from_sale
- Delists a property from sale.

### create_transaction
- Creates a new transaction for a property.

### verify_transaction
- Verifies a transaction.

### complete_transaction
- Completes a transaction and transfers ownership of the property.

### create_rental_agreement
- Creates a rental agreement for a property.

### pay_rent
- Pays rent for a rental agreement.

### end_rental_agreement
- Ends a rental agreement.

