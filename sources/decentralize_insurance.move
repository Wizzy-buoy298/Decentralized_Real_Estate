module decentralized_real_estate::real_estate {
    use sui::coin::{Coin, Self};
    use sui::sui::SUI;
    use sui::tx_context::{TxContext, sender};
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID, ID};
    use sui::transfer::{Self};
    use sui::event;
    use std::vector;

    // Errors Definitions
    const INSUFFICIENT_FUNDS: u64 = 1;
    const TRANSACTION_NOT_VERIFIED: u64 = 2;
    const PROPERTY_NOT_AVAILABLE: u64 = 3;
    const ONLY_OWNER_CAN_MANAGE: u64 = 4;
    const UNAUTHORIZED_ACCESS: u64 = 5;
    const VERIFICATION_FAILED: u64 = 6;
    const AGREEMENT_NOT_ACTIVE: u64 = 7;

    // Struct representing a property listing
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

    // Struct representing a transaction
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

    // Struct representing a rental agreement
    struct RentalAgreement has key, store {
        id: UID,
        property_id: u64,
        tenant: address,
        owner: address,
        rent_amount: u64,
        due_date: u64,
        is_active: bool,
    }

    // Events

    struct PropertyListed has copy, drop { id: ID, owner: address }
    struct TransactionCreated has copy, drop { id: ID, property_id: u64 }
    struct TransactionVerified has copy, drop { id: ID, verifier: address }
    struct TransactionCompleted has copy, drop { id: ID, property_id: u64 }
    struct RentalAgreementCreated has copy, drop { id: ID, property_id: u64 }

    // Create a new property listing
    public fun create_property(owner: address, location: vector<u8>, size: u64, price: u64, documents: vector<u8>, ctx: &mut TxContext) {
        let property_id = object::new(ctx);
        let property = Property {
            id: property_id,
            owner,
            location,
            size,
            price,
            balance: balance::zero(),
            is_for_sale: true,
            documents,
        };
        event::emit(
            PropertyListed { 
                id: object::uid_to_inner(&property.id), 
                owner 
            }
        );
        // Transfer the property object to the owner
        transfer::public_transfer(property, owner);
    }

    // List a property for sale
    public fun list_property_for_sale(property: &mut Property, price: u64, ctx: &mut TxContext) {
        assert!(sender(ctx) == property.owner, ONLY_OWNER_CAN_MANAGE);
        property.is_for_sale = true;
        property.price = price;
    }

    // Delist a property from sale
    public fun delist_property_from_sale(property: &mut Property, ctx: &mut TxContext) {
        assert!(sender(ctx) == property.owner, ONLY_OWNER_CAN_MANAGE);
        property.is_for_sale = false;
    }

    // Create a new transaction
    public fun create_transaction(property_id: u64, buyer: address, amount: u64, ctx: &mut TxContext): Transaction {
        let transaction_id = object::new(ctx);
        let transaction = Transaction {
            id: transaction_id,
            property_id,
            buyer,
            seller: sender(ctx),
            amount,
            verifiers: vector::empty<address>(),
            is_verified: false,
            is_completed: false,
        };
        event::emit(
            TransactionCreated { 
                id: object::uid_to_inner(&transaction.id), 
                property_id 
            }
        );
        transaction
    }

    // Verify a transaction
    public fun verify_transaction(transaction: &mut Transaction, verifier: address) {
        assert!(transaction.buyer != verifier, UNAUTHORIZED_ACCESS);
        assert!(transaction.seller != verifier, UNAUTHORIZED_ACCESS);

        // Ensure the verifier hasn't already verified this transaction
        assert!(!vector::contains(&transaction.verifiers, &verifier), VERIFICATION_FAILED);

        // Add verifier to the list of verifiers
        vector::push_back(&mut transaction.verifiers, verifier);

        // If sufficient verifiers have verified, mark the transaction as verified
        if (vector::length(&transaction.verifiers) > 2) {
            transaction.is_verified = true;
        }

        // Emit verification event
        event::emit(
            TransactionVerified { 
                id: object::uid_to_inner(&transaction.id), 
                verifier 
            }
        );
    }

    // Complete a transaction
    public fun complete_transaction(transaction: &mut Transaction, property: &mut Property, payment: Coin<SUI>) {
        assert!(transaction.is_verified, TRANSACTION_NOT_VERIFIED);
        assert!(coin::value(&payment) >= transaction.amount, INSUFFICIENT_FUNDS);
        assert!(property.is_for_sale, PROPERTY_NOT_AVAILABLE);
        
        // Transfer ownership of the property
        property.owner = transaction.buyer;
        property.is_for_sale = false;
        
        // Complete the transaction
        transaction.is_completed = true;
        
        // Transfer payment to the seller(owner of the property)
        let balance = coin::into_balance(payment);
        balance::join(&mut property.balance, balance);
        
        // Emit event for transaction completion
        event::emit(
            TransactionCompleted { 
                id: object::uid_to_inner(&transaction.id), 
                property_id: transaction.property_id 
            }
        );
    }

    // Create a rental agreement
    public fun create_rental_agreement(property_id: u64, tenant: address, rent_amount: u64, due_date: u64, ctx: &mut TxContext): RentalAgreement {
        let agreement_id = object::new(ctx);
        let agreement = RentalAgreement {
            id: agreement_id,
            property_id,
            tenant,
            owner: sender(ctx),
            rent_amount,
            due_date,
            is_active: true,
        };
        event::emit(
            RentalAgreementCreated { 
                id: object::uid_to_inner(&agreement.id), 
                property_id 
            }
        );
        agreement
    }

    // Pay rent
    public fun pay_rent(agreement: &mut RentalAgreement, property: &mut Property, payment: Coin<SUI>) {
        assert!(agreement.is_active, AGREEMENT_NOT_ACTIVE);
        assert!(coin::value(&payment) >= agreement.rent_amount, INSUFFICIENT_FUNDS);
        
        // Transfer payment to the property owner
        let balance = coin::into_balance(payment);
        balance::join(&mut property.balance, balance);
        
        // Update the due date for the next payment
        agreement.due_date += 30 * 24 * 60 * 60; // Assuming monthly rent
    }

    // End rental agreement
    public fun end_rental_agreement(agreement: &mut RentalAgreement, ctx: &mut TxContext) {
        assert!(sender(ctx) == agreement.owner, ONLY_OWNER_CAN_MANAGE);
        agreement.is_active = false;
    }

    // Update property details
    public fun update_property_details(property: &mut Property, location: vector<u8>, size: u64, price: u64, documents: vector<u8>, ctx: &mut TxContext) {
        assert!(sender(ctx) == property.owner, ONLY_OWNER_CAN_MANAGE);
        property.location = location;
        property.size = size;
        property.price = price;
        property.documents = documents;
    }

    // Calculate property tax (example implementation)
    public fun calculate_property_tax(property: &Property): u64 {
        property.price / 100 // Assuming 1% tax rate
    }

    // Additional functionality

    // Function to list all properties
    public fun list_all_properties(ctx: &TxContext): vector<Property> {
        let objects = object::list_all();
        let mut properties = vector::empty<Property>();
        for obj in objects {
            if (object::type(obj) == type_of<Property>()) {
                let property: Property = object::read(obj);
                properties.push_back(property);
            }
        }
        properties
    }

    // Function to list all transactions
    public fun list_all_transactions(ctx: &TxContext): vector<Transaction> {
        let objects = object::list_all();
        let mut transactions = vector::empty<Transaction>();
        for obj in objects {
            if (object::type(obj) == type_of<Transaction>()) {
                let transaction: Transaction = object::read(obj);
                transactions.push_back(transaction);
            }
        }
        transactions
    }

    // Function to list all rental agreements
    public fun list_all_rental_agreements(ctx: &TxContext): vector<RentalAgreement> {
        let objects = object::list_all();
        let mut agreements = vector::empty<RentalAgreement>();
        for obj in objects {
            if (object::type(obj) == type_of<RentalAgreement>()) {
                let agreement: RentalAgreement = object::read(obj);
                agreements.push_back(agreement);
            }
        }
        agreements
    }

    // Function to fetch all properties owned by a user
    public fun get_user_properties(user: address, ctx: &TxContext): vector<Property> {
        let objects = object::list_all();
        let mut properties = vector::empty<Property>();
        for obj in objects {
            if (object::type(obj) == type_of<Property>()) {
                let property: Property = object::read(obj);
                if (property.owner == user) {
                    properties.push_back(property);
                }
            }
        }
        properties
    }

    // Function to fetch all transactions involving a user
    public fun get_user_transactions(user: address, ctx: &TxContext): vector<Transaction> {
        let objects = object::list_all();
        let mut transactions = vector::empty<Transaction>();
        for obj in objects {
            if (object::type(obj) == type_of<Transaction>()) {
                let transaction: Transaction = object::read(obj);
                if (transaction.buyer == user || transaction.seller == user) {
                    transactions.push_back(transaction);
                }
            }
        }
        transactions
    }

    // Function to fetch all rental agreements for a user
    public fun get_user_rental_agreements(user: address, ctx: &TxContext): vector<RentalAgreement> {
        let objects = object::list_all();
        let mut agreements = vector::empty<RentalAgreement>();
        for obj in objects {
            if (object::type(obj) == type_of<RentalAgreement>()) {
                let agreement: RentalAgreement = object::read(obj);
                if (agreement.tenant == user || agreement.owner == user) {
                    agreements.push_back(agreement);
                }
            }
        }
        agreements
    }
}
