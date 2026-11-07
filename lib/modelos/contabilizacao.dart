/// Regra compartilhada entre os totais do app e os relatórios.
bool deveContabilizar({required bool ativa, required bool transferencia}) =>
    ativa && !transferencia;
