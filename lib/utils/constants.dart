import 'package:flutter/material.dart';

const String appName = 'BEE-Alert';
const String municipality = 'Municipality of Bacnotan, La Union';

const List<String> categories = [
  'Health',
  'Transportation',
  'Environment',
  'Consumer Issue',
  'Others',
];

const List<String> bacnotanBarangays = [
  'Agtipal',
  'Arosip',
  'Bacqui',
  'Bacsil',
  'Bagutot',
  'Ballogo',
  'Baroro',
  'Bitalag',
  'Bulala',
  'Burayoc',
  'Bussaoit',
  'Cabaroan',
  'Cabarsican',
  'Cabugao',
  'Calautit',
  'Carcarmay',
  'Casiaman',
  'Galongen',
  'Guinabang',
  'Legleg',
  'Lisqueb',
  'Mabanengbeng 1st',
  'Mabanengbeng 2nd',
  'Maragayap',
  'Nangalisan',
  'Nagatiran',
  'Nagsaraboan',
  'Nagsimbaanan',
  'Narra',
  'Ortega',
  'Paagan',
  'Pandan',
  'Pang-pang',
  'Poblacion',
  'Quirino',
  'Raois',
  'Salincob',
  'San Martin',
  'Santa Cruz',
  'Santa rita',
  'Sapilang',
  'Sayoan',
  'Sipulo',
  'Tammocalao',
  'Ubbog',
  'Oya-oy',
  'Zaragoza',
];

// Municipal contacts
class MunicipalContact {
  final String name;
  final String phone;
  final String email;
  const MunicipalContact({
    required this.name,
    required this.phone,
    required this.email,
  });
}

const List<MunicipalContact> municipalContacts = [
  MunicipalContact(
    name: "Municipal Mayor's Office",
    phone: '(072) 607-1234',
    email: 'mayor@bacnotan.gov.ph',
  ),
  MunicipalContact(
    name: 'Bacnotan Police Station',
    phone: '(072) 607-6079',
    email: 'police@bacnotan.gov.ph',
  ),
  MunicipalContact(
    name: 'Rural Health Unit',
    phone: '(072) 607-9012',
    email: 'health@bacnotan.gov.ph',
  ),
];

// Status values — must match web admin
const String statusPending = 'Pending';
const String statusOngoing = 'Ongoing';
const String statusCompleted = 'Completed';

// Status colors
const Color colorPending = Color(0xFFF59E0B);
const Color colorOngoing = Color(0xFF3B82F6);
const Color colorCompleted = Color(0xFF10B981);

// Gradient colors
const Color gradientStart = Color(0xFFF97316);
const Color gradientEnd = Color(0xFFFB923C);
