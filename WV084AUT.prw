#INCLUDE "PROTHEUS.CH"

/*/
  @param
  @return Não retorna nada
  @author Totvs Nordeste (Elvis Siqueira)
  @owner Totvs S/A
  @version Protheus 10, Protheus 11,Protheus 12
  @sample
  		Este Ponto de Entrada permite que a operação de um armazém receba os produtos unitizados 
        e realize o processo de registro de montagem do unitizador, sem que haja a necessidade 
        de abrir o invólucro e efetuar a leitura e a digitação de quantidade de cada um dos produtos contidos no unitizador.
  24/01/2024 - Desenvolvimento da Rotina.
/*/

User Function WV084AUT()
    Local aUnit     := {}
    
    MV_PAR60 := PARAMIXB[5] //ID do unitizador

Return aUnit
