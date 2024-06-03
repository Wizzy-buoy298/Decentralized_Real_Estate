module decentralized_real_estate::real_estate {
    use sui::coin::{Coin, Self};
    use sui::sui::SUI;
    use sui::tx_context::{TxContext, sender};
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID, ID};
    use sui::transfer::{Self};
    use sui::event;
    use std::vector;

    // Error Definitions
    const INSUFFICIENT_FUNDS: u64 = 1;
    const TRANSACTION_NOT_VERIFIED: u64 = 2;
    const PROPERTY_NOT_AVAILABLE: u64 = 3;
    const ONLY_OWNER_CAN_MANAGE: u64 = 4;
    const UNAUTHORIZED_ACCESS: u64 = 5;
    const VERIFICATION_FAILED: u64 = 6;
    const AGREEMENT_NOT_ACTIVE: u64 = 7;
    const INSUFFICIENT_VERIFICATION_REPUTATION: u64 = 8;

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
        verification_reputation: u64,
        fee_collected: bool,
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
    struct RentPaid has copy, drop { id: ID, tenant: address, owner: address, rent_amount: u64, due_date: u64 }
    struct RentalAgreementEnded has copy, drop { id: ID, property_id: u64 }
    struct PropertyUpdated has copy, drop { id: ID, owner: address }

    // Enhanced Error Handling and Access Control
    public fun ensure_owner(property: &Property, ctx: &TxContext) {
        assert!(sender(ctx) == property.owner, ONLY_OWNER_CAN_MANAGE);
    }

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
        ensure_owner(property, ctx);
        property.is_for_sale = true;
        property.price = price;
    }

    // Delist a property from sale
    public fun delist_property_from_sale(property: &mut Property, ctx: &mut TxContext) {
        ensure_owner(property, ctx);
        property.is_for_sale = false;
    }

    // Create a new transaction with transaction fee
    public fun create_transaction(property_id: u64, buyer: address, amount: u64, fee: u64, ctx: &mut TxContext): Transaction {
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
            verification_reputation: 0,
            fee_collected: false,
        };
        event::emit(
            TransactionCreated { 
                id: object::uid_to_inner(&transaction.id), 
                property_id 
            }
        );
        // Charge transaction fee
        let fee_payment = Coin<SUI>::zero(fee);
        coin::transfer(&fee_payment, transaction.seller);
        transaction.fee_collected = true;
        transaction
    }

    // Verify a transaction with optional reputation system
    public fun verify_transaction(transaction: &mut Transaction, verifier: address, reputation: u64) {
        assert!(transaction.buyer != verifier, UNAUTHORIZED_ACCESS);
        assert!(transaction.seller != verifier, UNAUTHORIZED_ACCESS);
        assert!(!vector::contains(&transaction.verifiers, &verifier), VERIFICATION_FAILED);

        vector::push_back(&mut transaction.verifiers, verifier);
        transaction.verification_reputation += reputation;

        // Example reputation threshold
        let required_reputation = 100;
        if transaction.verification_reputation >= required_reputation {
            transaction.is_verified = true;
        }

        event::emit(
            TransactionVerified { 
                id: object::uid_to_inner(&transaction.id), 
                verifier 
            }
        );
    }

    // Complete a transaction with reentrancy protection
    public fun complete_transaction(transaction: &mut Transaction, property: &mut Property, payment: Coin<SUI>, ctx: &mut TxContext) {
        assert!(transaction.is_verified, TRANSACTION_NOT_VERIFIED);
        assert!(coin::value(&payment) >= transaction.amount, INSUFFICIENT_FUNDS);
        assert!(property.is_for_sale, PROPERTY_NOT_AVAILABLE);

        property.owner = transaction.buyer;
        property.is_for_sale = false;
        transaction.is_completed = true;

        let balance = coin::into_balance(payment);
        balance::join(&mut property.balance, balance);

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

    // Pay rent with reentrancy protection
    public fun pay_rent(agreement: &mut RentalAgreement, property: &mut Property, payment: Coin<SUI>, ctx: &mut TxContext) {
        assert!(agreement.is_active, AGREEMENT_NOT_ACTIVE);
        assert!(coin::value(&payment) >= agreement.rent_amount, INSUFFICIENT_FUNDS);

        let balance = coin::into_balance(payment);
        balance::join(&mut property.balance, balance);

        agreement.due_date = agreement.due_date + 30 * 24 * 60 * 60; // Assuming monthly rent

        // Log rent payment
        event::emit(
            RentPaid {
                id: object::uid_to_inner(&agreement.id),
                tenant: agreement.tenant,
                owner: agreement.owner,
                rent_amount: agreement.rent_amount,
                due_date: agreement.due_date,
            }
        );
    }

    // End rental agreement
    public fun end_rental_agreement(agreement: &mut RentalAgreement, ctx: &mut TxContext) {
        ensure_owner(&agreement.owner, ctx);
        agreement.is_active = false;

        // Log rental agreement termination
        event::emit(
            RentalAgreementEnded {
                id: object::uid_to_inner(&agreement.id),
                property_id: agreement.property_id,
            }
        );
    }

    // Update property details
    public fun update_property_details(property: &mut Property, location: vector<u8>, size: u64, price: u64, documents: vector<u8>, ctx: &mut TxContext) {
        ensure_owner(property, ctx);
        property.location = location;
        property.size = size;
        property.price = price;
        property.documents = documents;

        // Log property update
        event::emit(
            PropertyUpdated {
                id: object::uid_to_inner(&property.id),
                owner: property.owner,
            }
        );
    }

    // Calculate property tax (example implementation)
    public fun calculate_property_tax(property: &Property): u64 {
        // Integration with external tax rate oracle needed here
        property.price / 100 // Assuming 1% tax rate
    }
}
