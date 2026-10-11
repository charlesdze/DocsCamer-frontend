class DocumentModel {
  final int idDocument;
  final String typeDocument;
  final String numeroPiece;
  final String statut;
  final String? qrCodeImage;

  DocumentModel({
    required this.idDocument,
    required this.typeDocument,
    required this.numeroPiece,
    required this.statut,
    this.qrCodeImage,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      idDocument: json['idDocument'] ?? 0,
      typeDocument: json['typeDocument'] ?? '',
      numeroPiece: json['numeroPiece'] ?? '',
      statut: json['statut'] ?? 'Valide',
      qrCodeImage: json['qrCodeImage'],
    );
  }
}