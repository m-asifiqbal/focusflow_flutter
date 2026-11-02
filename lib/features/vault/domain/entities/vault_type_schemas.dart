/// ============================================================
/// VAULT TYPE SCHEMAS — the fields of every schema-driven item type
/// ============================================================
///
/// One `switch` arm per type: sections of [VaultFieldSpec]s, in the order
/// the editor and the detail card show them. Built on every call (never
/// cached) because the labels are translated. Storage keys are permanent:
/// they are inside every saved payload and backup — add new keys freely,
/// never rename or reuse one for different data.
///
/// `sensitive` fields are masked (account / document numbers); `expiry`
/// dates feed the EXPIRED / EXPIRING badges. Keys `password` and `totp` are
/// the payload's own slots (see vault_field_spec.dart).
/// ============================================================
library;

import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/vault/domain/entities/vault_field_spec.dart';
import 'package:focusflow/features/vault/domain/entities/vault_item_record.dart';

const _multi = VaultFieldKind.multiline;
const _number = VaultFieldKind.number;
const _date = VaultFieldKind.date;
const _url = VaultFieldKind.url;
const _choice = VaultFieldKind.choice;
const _secret = VaultFieldKind.secret;
const _pin = VaultFieldKind.pin;
const _words = VaultCaps.words;
const _chars = VaultCaps.characters;

/// The sections of [type]; empty for the four built-in types.
List<VaultSection> vaultSectionsOf(VaultItemType type) => switch (type) {
  VaultItemType.bankAccount => [
    VaultSection(tr('Account'), [
      VaultFieldSpec('bank', tr('Bank name'), caps: _words),
      VaultFieldSpec('holder', tr('Account holder'), caps: _words),
      VaultFieldSpec(
        'kind',
        tr('Account type'),
        kind: _choice,
        options: [
          VaultOption('checking', tr('Checking / current')),
          VaultOption('savings', tr('Savings')),
          VaultOption('business', tr('Business')),
          VaultOption('joint', tr('Joint')),
          VaultOption('credit', tr('Credit')),
          VaultOption('loan', tr('Loan')),
          VaultOption('investment', tr('Investment')),
          VaultOption('other', tr('Other')),
        ],
      ),
      VaultFieldSpec(
        'number',
        tr('Account number'),
        sensitive: true,
        mono: true,
      ),
      VaultFieldSpec(
        'iban',
        tr('IBAN'),
        sensitive: true,
        mono: true,
        caps: _chars,
        format: VaultFieldFormat.iban,
      ),
      VaultFieldSpec(
        'bic',
        tr('SWIFT / BIC'),
        mono: true,
        caps: _chars,
        format: VaultFieldFormat.bic,
      ),
      VaultFieldSpec('routing', tr('Routing / sort / IFSC code'), mono: true),
      VaultFieldSpec('branch', tr('Branch'), caps: _words),
      VaultFieldSpec('currency', tr('Currency'), caps: _chars, hint: 'USD'),
      VaultFieldSpec('opened', tr('Opened on'), kind: _date),
    ]),
    VaultSection(tr('Online banking'), [
      VaultFieldSpec('loginId', tr('Customer / user ID')),
      VaultFieldSpec('password', tr('Password'), kind: VaultFieldKind.password),
      VaultFieldSpec('url', tr('Website'), kind: _url),
      VaultFieldSpec('totp', tr('2FA secret (TOTP)'), kind: VaultFieldKind.totp),
    ]),
    VaultSection(tr('PINs & security'), [
      VaultFieldSpec('atmPin', tr('ATM / debit PIN'), kind: _pin),
      VaultFieldSpec('phonePin', tr('Phone banking PIN'), kind: _pin),
      VaultFieldSpec('memorable', tr('Memorable word'), kind: _secret),
    ]),
    VaultSection(tr('Contact'), [
      VaultFieldSpec('phone', tr('Bank phone'), kind: VaultFieldKind.phone),
    ]),
  ],
  VaultItemType.cryptoWallet => [
    VaultSection(tr('Wallet'), [
      VaultFieldSpec('name', tr('Wallet or exchange'), caps: _words),
      VaultFieldSpec('network', tr('Network'), caps: _words),
      VaultFieldSpec('address', tr('Public address'), mono: true),
    ]),
    VaultSection(tr('Recovery & keys'), [
      VaultFieldSpec(
        'seed',
        tr('Recovery phrase'),
        kind: _secret,
        mono: true,
      ),
      VaultFieldSpec('privateKey', tr('Private key'), kind: _secret, mono: true),
      VaultFieldSpec('walletPin', tr('Wallet PIN'), kind: _pin),
    ]),
    VaultSection(tr('Exchange sign-in'), [
      VaultFieldSpec('loginId', tr('Username / email')),
      VaultFieldSpec('password', tr('Password'), kind: VaultFieldKind.password),
      VaultFieldSpec('url', tr('Website'), kind: _url),
      VaultFieldSpec('totp', tr('2FA secret (TOTP)'), kind: VaultFieldKind.totp),
    ]),
  ],
  VaultItemType.insurance => [
    VaultSection(tr('Policy'), [
      VaultFieldSpec('provider', tr('Insurer'), caps: _words),
      VaultFieldSpec(
        'kind',
        tr('Cover type'),
        kind: _choice,
        options: [
          VaultOption('health', tr('Health')),
          VaultOption('life', tr('Life')),
          VaultOption('car', tr('Car')),
          VaultOption('home', tr('Home')),
          VaultOption('travel', tr('Travel')),
          VaultOption('other', tr('Other')),
        ],
      ),
      VaultFieldSpec('policy', tr('Policy number'), sensitive: true, mono: true),
      VaultFieldSpec('holder', tr('Policyholder'), caps: _words),
      VaultFieldSpec('plan', tr('Plan / coverage')),
      VaultFieldSpec('premium', tr('Premium')),
      VaultFieldSpec('start', tr('Start date'), kind: _date),
      VaultFieldSpec('renewal', tr('Renewal date'), kind: _date, expiry: true),
    ]),
    VaultSection(tr('Contact'), [
      VaultFieldSpec('claimsPhone', tr('Claims phone'), kind: VaultFieldKind.phone),
      VaultFieldSpec('agent', tr('Agent / broker'), caps: _words),
      VaultFieldSpec('url', tr('Website'), kind: _url),
    ]),
  ],
  VaultItemType.identity => [
    VaultSection(tr('Personal'), [
      VaultFieldSpec('fullName', tr('Full name'), caps: _words),
      VaultFieldSpec('dob', tr('Date of birth'), kind: _date),
      VaultFieldSpec('nationality', tr('Nationality'), caps: _words),
      VaultFieldSpec('taxId', tr('Tax ID / SSN'), sensitive: true, mono: true),
    ]),
    VaultSection(tr('Contact'), [
      VaultFieldSpec('email', tr('Email'), kind: VaultFieldKind.email),
      VaultFieldSpec('phone', tr('Phone'), kind: VaultFieldKind.phone),
      VaultFieldSpec('address', tr('Address'), kind: _multi, caps: VaultCaps.sentences),
      VaultFieldSpec('city', tr('City'), caps: _words),
      VaultFieldSpec('region', tr('State / province'), caps: _words),
      VaultFieldSpec('postal', tr('Postal code'), caps: _chars),
      VaultFieldSpec('country', tr('Country'), caps: _words),
    ]),
  ],
  VaultItemType.passport => [
    VaultSection(tr('Document'), [
      VaultFieldSpec('fullName', tr('Full name'), caps: _words),
      VaultFieldSpec(
        'number',
        tr('Passport number'),
        sensitive: true,
        mono: true,
        caps: _chars,
      ),
      VaultFieldSpec('nationality', tr('Nationality'), caps: _words),
      VaultFieldSpec('dob', tr('Date of birth'), kind: _date),
      VaultFieldSpec('pob', tr('Place of birth'), caps: _words),
    ]),
    VaultSection(tr('Validity'), [
      VaultFieldSpec('issued', tr('Issue date'), kind: _date),
      VaultFieldSpec('expires', tr('Expiry date'), kind: _date, expiry: true),
      VaultFieldSpec('country', tr('Issuing country'), caps: _words),
      VaultFieldSpec('authority', tr('Issuing authority'), caps: _words),
    ]),
  ],
  VaultItemType.driverLicense => [
    VaultSection(tr('Document'), [
      VaultFieldSpec('fullName', tr('Full name'), caps: _words),
      VaultFieldSpec(
        'number',
        tr('Licence number'),
        sensitive: true,
        mono: true,
        caps: _chars,
      ),
      VaultFieldSpec('class', tr('Licence class'), caps: _chars),
      VaultFieldSpec('dob', tr('Date of birth'), kind: _date),
    ]),
    VaultSection(tr('Validity'), [
      VaultFieldSpec('issued', tr('Issue date'), kind: _date),
      VaultFieldSpec('expires', tr('Expiry date'), kind: _date, expiry: true),
      VaultFieldSpec('issuer', tr('Issuing state / country'), caps: _words),
    ]),
    VaultSection(tr('Details'), [
      VaultFieldSpec('address', tr('Address'), kind: _multi, caps: VaultCaps.sentences),
      VaultFieldSpec('restrictions', tr('Restrictions / endorsements')),
    ]),
  ],
  VaultItemType.nationalId => [
    VaultSection(tr('Document'), [
      VaultFieldSpec('fullName', tr('Full name'), caps: _words),
      VaultFieldSpec(
        'number',
        tr('ID number'),
        sensitive: true,
        mono: true,
        caps: _chars,
      ),
      VaultFieldSpec('dob', tr('Date of birth'), kind: _date),
      VaultFieldSpec('address', tr('Address'), kind: _multi, caps: VaultCaps.sentences),
    ]),
    VaultSection(tr('Validity'), [
      VaultFieldSpec('issued', tr('Issue date'), kind: _date),
      VaultFieldSpec('expires', tr('Expiry date'), kind: _date, expiry: true),
      VaultFieldSpec('country', tr('Issuing country'), caps: _words),
    ]),
  ],
  VaultItemType.medical => [
    VaultSection(tr('Coverage'), [
      VaultFieldSpec('insurer', tr('Health insurer'), caps: _words),
      VaultFieldSpec('memberId', tr('Member ID'), sensitive: true, mono: true),
      VaultFieldSpec('group', tr('Group number'), mono: true),
      VaultFieldSpec('holder', tr('Member name'), caps: _words),
      VaultFieldSpec('insurerPhone', tr('Insurer phone'), kind: VaultFieldKind.phone),
    ]),
    VaultSection(tr('Medical info'), [
      VaultFieldSpec('dob', tr('Date of birth'), kind: _date),
      VaultFieldSpec(
        'blood',
        tr('Blood type'),
        kind: _choice,
        options: const [
          VaultOption('A+', 'A+'),
          VaultOption('A-', 'A−'),
          VaultOption('B+', 'B+'),
          VaultOption('B-', 'B−'),
          VaultOption('AB+', 'AB+'),
          VaultOption('AB-', 'AB−'),
          VaultOption('O+', 'O+'),
          VaultOption('O-', 'O−'),
        ],
      ),
      VaultFieldSpec('allergies', tr('Allergies'), kind: _multi, caps: VaultCaps.sentences),
      VaultFieldSpec(
        'conditions',
        tr('Conditions & medication'),
        kind: _multi,
        caps: VaultCaps.sentences,
      ),
    ]),
    VaultSection(tr('Contacts'), [
      VaultFieldSpec('doctor', tr('Doctor'), caps: _words),
      VaultFieldSpec('doctorPhone', tr('Doctor phone'), kind: VaultFieldKind.phone),
      VaultFieldSpec('emergency', tr('Emergency contact'), caps: _words),
      VaultFieldSpec('emergencyPhone', tr('Emergency phone'), kind: VaultFieldKind.phone),
    ]),
  ],
  VaultItemType.emailAccount => [
    VaultSection(tr('Account'), [
      VaultFieldSpec('address', tr('Email address'), kind: VaultFieldKind.email),
      VaultFieldSpec('provider', tr('Provider'), caps: _words),
    ]),
    VaultSection(tr('Sign-in'), [
      VaultFieldSpec('password', tr('Password'), kind: VaultFieldKind.password),
      VaultFieldSpec('totp', tr('2FA secret (TOTP)'), kind: VaultFieldKind.totp),
      VaultFieldSpec('url', tr('Website'), kind: _url),
    ]),
    VaultSection(tr('Mail servers'), [
      VaultFieldSpec('imapHost', tr('Incoming server (IMAP)'), mono: true),
      VaultFieldSpec('imapPort', tr('Incoming port'), kind: _number, hint: '993'),
      VaultFieldSpec('smtpHost', tr('Outgoing server (SMTP)'), mono: true),
      VaultFieldSpec('smtpPort', tr('Outgoing port'), kind: _number, hint: '587'),
    ]),
    VaultSection(tr('Recovery'), [
      VaultFieldSpec('recoveryEmail', tr('Recovery email'), kind: VaultFieldKind.email),
      VaultFieldSpec('recoveryPhone', tr('Recovery phone'), kind: VaultFieldKind.phone),
    ]),
  ],
  VaultItemType.server => [
    VaultSection(tr('Connection'), [
      VaultFieldSpec('host', tr('Host / IP address'), mono: true),
      VaultFieldSpec('port', tr('Port'), kind: _number, hint: '22'),
      VaultFieldSpec(
        'service',
        tr('Service type'),
        kind: _choice,
        options: [
          VaultOption('ssh', tr('SSH')),
          VaultOption('sftp', tr('FTP / SFTP')),
          VaultOption('rdp', tr('Remote desktop')),
          VaultOption('vpn', tr('VPN')),
          VaultOption('database', tr('Database')),
          VaultOption('panel', tr('Control panel')),
          VaultOption('other', tr('Other')),
        ],
      ),
      VaultFieldSpec('database', tr('Database name')),
      VaultFieldSpec('console', tr('Console / dashboard URL'), kind: _url),
    ]),
    VaultSection(tr('Sign-in'), [
      VaultFieldSpec('username', tr('Username')),
      VaultFieldSpec('password', tr('Password'), kind: VaultFieldKind.password),
      VaultFieldSpec('totp', tr('2FA secret (TOTP)'), kind: VaultFieldKind.totp),
    ]),
    VaultSection(tr('Keys'), [
      VaultFieldSpec('privateKey', tr('Private key'), kind: _secret, mono: true),
      VaultFieldSpec('passphrase', tr('Key passphrase'), kind: _secret),
    ]),
  ],
  VaultItemType.apiKey => [
    VaultSection(tr('Service'), [
      VaultFieldSpec('service', tr('Service'), caps: _words),
      VaultFieldSpec(
        'env',
        tr('Environment'),
        kind: _choice,
        options: [
          VaultOption('production', tr('Production')),
          VaultOption('staging', tr('Staging')),
          VaultOption('development', tr('Development')),
          VaultOption('test', tr('Test')),
        ],
      ),
      VaultFieldSpec('endpoint', tr('Endpoint URL'), kind: _url),
    ]),
    VaultSection(tr('Credentials'), [
      VaultFieldSpec('key', tr('API key'), kind: _secret, mono: true),
      VaultFieldSpec('secret', tr('API secret'), kind: _secret, mono: true),
      VaultFieldSpec('clientId', tr('Client ID'), mono: true),
      VaultFieldSpec('token', tr('Access token'), kind: _secret, mono: true),
    ]),
    VaultSection(tr('Validity'), [
      VaultFieldSpec('scopes', tr('Scopes / permissions')),
      VaultFieldSpec('created', tr('Created on'), kind: _date),
      VaultFieldSpec('expires', tr('Expires on'), kind: _date, expiry: true),
    ]),
  ],
  VaultItemType.softwareLicense => [
    VaultSection(tr('Product'), [
      VaultFieldSpec('product', tr('Product'), caps: _words),
      VaultFieldSpec('version', tr('Version')),
    ]),
    VaultSection(tr('Licence'), [
      VaultFieldSpec('key', tr('Licence key'), kind: _secret, mono: true),
      VaultFieldSpec('licensee', tr('Licensed to'), caps: _words),
      VaultFieldSpec('email', tr('Registered email'), kind: VaultFieldKind.email),
      VaultFieldSpec('seats', tr('Seats / devices'), kind: _number),
    ]),
    VaultSection(tr('Purchase'), [
      VaultFieldSpec('order', tr('Order number'), mono: true),
      VaultFieldSpec('purchased', tr('Purchase date'), kind: _date),
      VaultFieldSpec('expires', tr('Expiry date'), kind: _date, expiry: true),
      VaultFieldSpec('url', tr('Vendor website'), kind: _url),
    ]),
  ],
  VaultItemType.membership => [
    VaultSection(tr('Membership'), [
      VaultFieldSpec('org', tr('Organisation'), caps: _words),
      VaultFieldSpec('member', tr('Member ID'), mono: true),
      VaultFieldSpec('tier', tr('Membership level'), caps: _words),
      VaultFieldSpec('holder', tr('Member name'), caps: _words),
    ]),
    VaultSection(tr('Validity'), [
      VaultFieldSpec('since', tr('Member since'), kind: _date),
      VaultFieldSpec('expires', tr('Expiry date'), kind: _date, expiry: true),
    ]),
    VaultSection(tr('Contact'), [
      VaultFieldSpec('phone', tr('Phone'), kind: VaultFieldKind.phone),
      VaultFieldSpec('url', tr('Website'), kind: _url),
      VaultFieldSpec('pin', tr('PIN'), kind: _pin),
    ]),
  ],
  VaultItemType.vehicle => [
    VaultSection(tr('Vehicle'), [
      VaultFieldSpec('model', tr('Make & model'), caps: _words),
      VaultFieldSpec('plate', tr('Registration plate'), mono: true, caps: _chars),
      VaultFieldSpec('vin', tr('VIN'), mono: true, caps: _chars),
      VaultFieldSpec('year', tr('Year'), kind: _number, hint: '2024'),
      VaultFieldSpec('color', tr('Colour'), caps: _words),
      VaultFieldSpec('owner', tr('Owner'), caps: _words),
    ]),
    VaultSection(tr('Papers'), [
      VaultFieldSpec('regExpires', tr('Registration expiry'), kind: _date, expiry: true),
      VaultFieldSpec('insExpires', tr('Insurance expiry'), kind: _date, expiry: true),
      VaultFieldSpec('inspection', tr('Next inspection'), kind: _date, expiry: true),
      VaultFieldSpec('policy', tr('Insurance policy no.'), mono: true),
    ]),
    VaultSection(tr('Support'), [
      VaultFieldSpec('assistance', tr('Roadside assistance phone'), kind: VaultFieldKind.phone),
    ]),
  ],
  _ => const [],
};
