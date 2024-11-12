#Include 'Protheus.ch'

//------------------------------------------------------------
/*/ Rotina MATI681

  Ponto de entrada MATI681CRG
    
   Permite que sejam adicionadas informações para realizar
   o apontamento da produção e apontamento de parada no 
   Protheus. Não será permitido alterar nenhuma informação
   que é recebida por meio do XML do apontamento de produção.

   Para identificar se será realizada a execução para o 
   apontamento de parada ou para o apontamento de produção,
   deve-se verificar o campo H6_TIPO conforme descrito no
   exemplo do ponto de entrada. Quando H6_TIPO for igual
   a "P", significa que está sendo executada a rotina de
   apontamento da produção. Quando for igual a "I", significa
   que está sendo executada a rotina de apontamento de parada.

   Implementado para:
      - Gravar o campo 'H6_XPALETE'.
   
  @param ParamIxb = XML de envio
  @author Anderson Almeida - TOTVS
  @since   02/09/2024 - Desenvolvimento da Rotina.
/*/
//------------------------------------------------------------- 
User Function MATI681CRG()
  Local aRet        := {} 
  Local nPos        := aScan(ParamIxB,{|x| AllTrim(x[1]) == "H6_TIPO"})
  Local cUnitizador := oXml:_TotvsMessage:_BusinessMessage:_BusinessContent:_IDREPORT:Text

  If ParamIxB[nPos][02] == "P"       // Apontamento de produ��o
     aAdd(aRet,{"H6_XPALETE", StrZero(Val(cUnitizador),FWTamSX3("H6_XPALETE")[1]), Nil}) 
   else
     // Apontamento de parada
  EndIf
Return aRet
