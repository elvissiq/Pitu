#INCLUDE "PROTHEUS.CH"
//--------------------------------------------------------------
/*/ Rotina MATA250

   Ponto-de-Entrada: A250WMSO - Ponto de entrada no apontamento
                                da Produção.

 @Retorna o Endereço da DOCA do Produto
 @author Anderson (TOTVS)
 @since 22/08/2024
/*/
// -------------------------------------------------------------
User Function A250WMSO()
  Local aEnd := {}

  aAdd(aEnd, "DOCAE")
Return aEnd
