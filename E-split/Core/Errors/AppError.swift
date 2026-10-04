import Foundation

enum AppError: LocalizedError, Equatable {
    case groupNameRequired
    case memberNameRequired
    case amountMustBeGreaterThanZero
    case descriptionRequired
    case atLeastOneParticipantRequired
    case splitAmountsMustEqualTotal(expected: Decimal)
    case percentagesMustTotalOneHundred
    case sharesMustBeValid
    case invalidSplit
    case balancesMustSumToZero
    case groupNotFound
    case expenseNotFound
    case settlementNotFound
    case memberNotFound
    case cannotRemoveLastAdmin
    case cannotRemoveLastMember
    case saveFailed
    case loadFailed
    case emailRequired
    case invalidEmail
    case invalidCredentials
    case emailAlreadyRegistered
    case emailNotConfirmed
    case confirmationEmailFailed
    case emailAuthDisabled
    case notAuthenticated
    case invalidInvite
    case memberEmailRequired
    case memberNeedsAccount
    case unknown

    var errorDescription: String? {
        switch self {
        case .groupNameRequired:
            return "Please enter a group name."
        case .memberNameRequired:
            return "Please enter a member name."
        case .amountMustBeGreaterThanZero:
            return "Amount must be greater than zero."
        case .descriptionRequired:
            return "Please enter a description."
        case .atLeastOneParticipantRequired:
            return "Select at least one person to split with."
        case .splitAmountsMustEqualTotal(let expected):
            return "Split amounts must equal \(MoneyFormatter.string(from: expected))."
        case .percentagesMustTotalOneHundred:
            return "Percentages must total 100%."
        case .sharesMustBeValid:
            return "Each participant needs a valid share greater than zero."
        case .invalidSplit:
            return "Unable to calculate this split. Please check the amounts."
        case .balancesMustSumToZero:
            return "Balances are out of balance. Please review the expense."
        case .groupNotFound:
            return "This group could not be found."
        case .expenseNotFound:
            return "This expense could not be found."
        case .settlementNotFound:
            return "This settlement could not be found."
        case .memberNotFound:
            return "This member could not be found."
        case .cannotRemoveLastAdmin:
            return "A group needs at least one admin."
        case .cannotRemoveLastMember:
            return "A group needs at least one member."
        case .saveFailed:
            return "Unable to save. Please try again."
        case .loadFailed:
            return "Unable to load data. Please try again."
        case .emailRequired:
            return "Please enter your email."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .emailAlreadyRegistered:
            return "An account with this email already exists."
        case .emailNotConfirmed:
            return "Supabase still requires email confirmation, so sign-in cannot finish. Open Authentication → Providers → Email, turn Confirm email off, tap Save, then Log in. If this email was used earlier, delete that user in Authentication → Users and create the account again."
        case .confirmationEmailFailed:
            return "Unable to create the account because the confirmation email could not be sent. In Supabase, open Authentication → Providers → Email and turn off Confirm email, then try again."
        case .emailAuthDisabled:
            return "Email sign-in is turned off in Supabase. Open Authentication → Providers → Email, enable Email, keep Confirm email off, tap Save, then try again."
        case .notAuthenticated:
            return "Please log in to continue."
        case .invalidInvite:
            return "This invite link is invalid or has expired."
        case .memberEmailRequired:
            return "Enter the email they used to create their account."
        case .memberNeedsAccount:
            return "No account exists for this email. Ask them to sign up, then add them again or share the group invite link."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
