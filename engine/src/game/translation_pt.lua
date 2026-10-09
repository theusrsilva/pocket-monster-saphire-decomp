-- Tradução das falas para o português (PT-BR).
-- Chave = "BB:AAAA", banco e endereço do trecho de fala na ROM (ver docs/FINDINGS.md, script de
-- eventos); valor = uma string por página do trecho (as páginas mudam a cada troca de falante,
-- comando EA). O texto original não fica no repositório: ele é lido da ROM do jogador.
-- Nomes seguem o modo "oficial": Pokémon com nome oficial, Xiaozhi = Ash, Wuzhang = Jessie,
-- Xiaochilang = James, Mi = Meowth, Rocket Brigade = Equipe Rocket, Phoenix = Ho-Oh,
-- Lokia = Lugia, Doctor Darkwood = Professor Carvalho, "magic baby" = Pokémon,
-- Palaestra = Ginásio.
return {
  -- Introdução (script $20, mensagens 1-5)
  ["5D:50DC"] = { "Depois de conseguir a insígnia maligna, perdida havia muito tempo, a Equipe Rocket destruiu com crueldade a paz do mundo Pokémon e, pior ainda, saqueou loucamente os Pokémon dos treinadores." },
  ["5D:5189"] = { "Ao descobrir isso, Ash e seus amigos decidiram acabar com a maldade deles, mas acabaram aprisionados." },
  ["5D:51EC"] = { "Para encontrar os treinadores desaparecidos e resgatar os Pokémon roubados pela Equipe Rocket..." },
  ["5D:524E"] = { "Pikachu, mesmo sem notícias de Ash, decide partir para a batalha com seus amigos. Mas o caminho está cheio de problemas complicados, e desta vez..." },
  ["5D:52EB"] = { "Será que eles vão conseguir sair de todos esses problemas sãos e salvos?" },

  -- Fase 1: Cidade ChangPan
  ["5D:532C"] = { "Deixe-me cuidar de vocês!" },
  ["5D:5351"] = { "A mamãe acabou de me comprar uns doces. Tome um para comer no caminho. Você ganhou Pão!" },
  ["5D:53B3"] = { "O Ash não volta para casa há vários dias. Você vai procurar por ele? Então leve este tesouro! Você ganhou a Insígnia da Agilidade!" },
  ["5D:542A"] = { "Se você explorar bem as casas e vilas, vai encontrar tesouros ou pistas importantes." },
  ["5D:5489"] = { "Você ganhou um Doce!" },
  ["5D:54A2"] = { "Você ganhou um Suco!" },
  ["5D:54BB"] = { "Você ganhou uma Pedra da Vida!" },
  ["5D:54E0"] = { "Você ganhou a Insígnia do Equilíbrio!" },

  -- Fase 2: Bosque ChangPan
  ["5D:550A"] = { "Deixe-me cuidar de vocês!" },
  ["5D:552F"] = { "Escute! As insígnias são essenciais para evoluir. Quando conseguir uma, lembre-se de ir à Aliança Pokémon para fazer a evolução!" },
  ["5D:55B8"] = { "No Instituto você aprende sobre os tipos. Não se esqueça de falar com o Professor Carvalho!" },
  ["5D:561A"] = { "Você ganhou um Pão!" },
  ["5D:5633"] = { "Você ganhou um Suco!" },
  ["5D:564C"] = { "Você ganhou uma Pedra da Fênix!" },
  ["5D:566F"] = { "Ha! Já que você está correndo tanto perigo, vou lhe dar um tesouro: a Insígnia da Defesa!" },
  ["5D:56BD"] = {
    "Você ganhou a Insígnia da Força!",
    "Espere um pouco! Você está procurando o seu treinador? Posso ir junto? Charmander entrou no time!",
    "Gua! Gua! Eu também quero ir. Quero encontrar aqueles malfeitores. Vamos lá! Bulbasaur entrou no time!",
  },

  -- Fase 3: Cidade Niby
  ["5D:57CC"] = { "Deixe-me cuidar de vocês!" },
  ["5D:57F1"] = { "Achei isto anteontem, mas não me serve para nada. Fique com ela! Você ganhou a Insígnia da Agilidade!" },
  ["5D:5871"] = { "Conhece a lenda do Monte da Lua? Dizem que lá está escondida uma Pedra da Lua com poderes misteriosos!" },
  ["5D:58E3"] = { "Você ganhou um Pão!" },
  ["5D:58FC"] = { "Você ganhou uma Pedra da Vida!" },
  ["5D:591A"] = { "Você ganhou uma Pedra do Olho!" },
  ["5D:593A"] = { "Você ganhou a Insígnia da Força!" },

  -- Fase 4: Cidade Jiegeng
  ["5D:5961"] = { "Deixe-me cuidar de vocês!" },
  ["5D:5986"] = { "Há um barqueiro na Cabana do Cabo. Ele adora a Pedra da Lua. Se você conseguir uma para ele, quem sabe ele não lhe dá um bom tesouro?" },
  ["5D:5A06"] = { "Que calor! Estou tomando uma bebida bem gelada. Quer um pouco? Você ganhou um Suco!" },
  ["5D:5A71"] = { "Você ganhou um Doce!" },
  ["5D:5A8A"] = { "Você ganhou uma Pedra do Voo!" },
  ["5D:5AAD"] = { "Meu marido deixou isto. Agora é seu! Você ganhou a Insígnia da Defesa!" },
  ["5D:5AFE"] = {
    "Você ganhou a Insígnia do Equilíbrio!",
    "Escapei por sorte, mas os outros foram sequestrados. Vou procurar a minha família. Vamos! Machop entrou no time!",
    "Sinto muita falta do meu treinador! Quero viver essa aventura com vocês, assim fica mais fácil procurá-lo. Abra entrou no time!",
  },

  -- Fase 5: Monte da Lua
  ["5D:5C45"] = { "Deixe-me cuidar de vocês!" },
  ["5D:5C6A"] = { "Dizem que nesta montanha vive um Pokémon que canta! Ah, como eu queria ter um bichinho tão fofo!" },
  ["5D:5CD6"] = { "Os outros treinadores devem estar presos na torre mais distante. Ah, e tenho uma coisa boa para você! Você ganhou a Insígnia do Equilíbrio!" },
  ["5D:5D68"] = { "Você ganhou uma Pedra do Espírito!" },
  ["5D:5D87"] = { "Você ganhou uma Pedra das Chamas!" },
  ["5D:5DA9"] = { "Oh! Você vai salvar a paz desta ilha? Muito obrigado! Você ganhou a Insígnia do Superpoder!" },
  ["5D:5E17"] = {
    "Você ganhou a Pedra da Lua!",
    "Ai, ai! Que dor de cabeça! Hã? Você me salvou? Só me lembro de estar sendo controlado por um poder desconhecido. Depois disso, não me lembro de nada!",
    "Obrigado pela ajuda! Posso ir com vocês? Sei curar os feridos, vou ser útil! Igglybuff entrou no time!",
  },

  -- Fase 6: Cidade Folha Seca
  ["5D:5F53"] = { "Deixe-me cuidar de vocês!" },
  ["5D:5F78"] = { "Com as pedras que você encontrar, dá para aumentar os limites das habilidades dos seus Pokémon." },
  ["5D:5FDD"] = { "Você ganhou a Insígnia da Força!" },
  ["5D:5FFF"] = { "Você ganhou uma Pedra da Vida!" },
  ["5D:6025"] = {
    "Você ganhou a Insígnia da Agilidade!",
    "Hmm! Ouvi dizer que vocês vão enfrentar a Equipe Rocket, não é? Mareep entrou no time!",
    "A Equipe Rocket é mesmo do mal. Bom, vamos juntos, assim um protege o outro. Mudkip entrou no time!",
  },

  -- Fase 7: Ruínas de Astana
  ["5D:6146"] = { "Deixe-me cuidar de vocês!" },
  ["5D:616B"] = { "Oh! Muito bem! Tenho uma coisa boa para você! Ha, ha! Você ganhou a Insígnia da Defesa!" },
  ["5D:61B9"] = { "Há muitos Ginásios pelas cidades. São ótimos lugares para treinar e ficar mais forte!" },
  ["5D:6221"] = { "Você ganhou um Leite!" },
  ["5D:6235"] = { "Você ganhou uma Pedra das Chamas!" },
  ["5D:625C"] = {
    "Você ganhou a Insígnia do Superpoder!",
    "Já me decidi: vou me arriscar com vocês. Certo! Dratini entrou no time!",
  },

  -- Fase 8: A Toca do Rato
  ["5D:62DF"] = { "Deixe-me cuidar de vocês!" },
  ["5D:6304"] = { "Faz tempo que ninguém me visita, então isto fica com você. Você ganhou a Insígnia da Força!" },
  ["5D:6360"] = { "Muito, muito longe, existe uma torre escarlate onde se esconde um Pokémon lendário!" },
  ["5D:63B7"] = { "Você ganhou um Pão!" },
  ["5D:63D0"] = { "Você ganhou uma Pedra da Vida!" },
  ["5D:63EE"] = { "Você ganhou uma Pedra da Fênix!" },
  ["5D:6416"] = {
    "Você ganhou a Insígnia da Defesa!",
    "Já que vocês insistem em ir, vou junto, mesmo a contragosto! Não me olhe assim, eu sou desse jeito. Larvitar entrou no time!",
  },

  -- Fase 9: Cabana do Cabo (exige a Pedra da Lua)
  ["5D:64AD"] = { "Deixe-me cuidar de vocês!" },
  ["5D:64D2"] = { "Está procurando o barqueiro? A casa dele não fica longe daqui. Você ganhou a Insígnia do Equilíbrio!" },
  ["5D:653B"] = { "Eu ia lhe dar um passe, mas um monstro o roubou há pouco tempo!" },
  ["5D:6590"] = { "Que doce delicioso! Já que você viu, fique com um. Você ganhou um Doce!" },
  ["5D:65E8"] = { "Você ganhou a Insígnia do Superpoder!" },
  ["5D:660C"] = { "Você ganhou uma Pedra do Olho!" },
  ["5D:662D"] = { "Ai, ai! Nós nos rendemos! Devolvemos o passe, por favor nos perdoe! Você ganhou o Passe!" },
  ["5D:6696"] = { "Ah, como eu queria ter a linda Pedra da Lua! Você consegue uma para mim?" },
  ["5D:66D6"] = { "Oh! Olhe que cor linda! Que maravilha! Eu ia lhe dar um tesouro, mas, que pena, um monstro acabou de roubá-lo." },

  -- Fase 10: Cidade Rosa
  ["5D:675E"] = { "Deixe-me cuidar de vocês!" },
  ["5D:6783"] = { "Puxa! Você parece tão esperto que vou lhe dar um tesouro! Você ganhou a Insígnia da Agilidade!" },
  ["5D:67D9"] = { "Como uns monstros enlouquecidos andam aparecendo e sumindo, a guarda da Cidade Arco-Íris ficou mais rígida. Para entrar, você precisa do passe." },
  ["5D:686B"] = { "Você ganhou um Leite!" },
  ["5D:687E"] = { "Você ganhou uma Pedra do Espírito!" },
  ["5D:68A5"] = {
    "Você ganhou a Insígnia do Equilíbrio!",
    "Uuh... uuh... que dor! Não sei o que aconteceu! Perdi a consciência depois de ver a Equipe Rocket.",
  },

  -- Fase 11: Cidade Arco-Íris (exige o Passe)
  ["5D:6945"] = { "Deixe-me cuidar de vocês!" },
  ["5D:696A"] = { "Tome, um bom tesouro! Não precisa agradecer, ha! Você ganhou a Insígnia da Força!" },
  ["5D:69BD"] = { "Nossa cidade tem a vigilância mais rígida de todas. Isso não incomoda você?" },
  ["5D:69FF"] = { "Você ganhou um Doce!" },
  ["5D:6A11"] = { "Você ganhou um Suco!" },
  ["5D:6A2B"] = { "Obrigado por vir me visitar! Você ganhou uma Pedra do Voo!" },
  ["5D:6A66"] = { "Você ganhou a Insígnia da Agilidade!" },
  ["5D:6A8C"] = { "Não, não! Quem não é treinador de equipe não pode entrar! Só com o passe!" },
  ["5D:6AE5"] = { "Bem-vindo à linda Cidade Arco-Íris! A paisagem aqui é belíssima!" },

  -- Fase 12: Cidade Dourada
  ["5D:6B29"] = { "Deixe-me cuidar de vocês!" },
  ["5D:6B4E"] = { "Aqui perto há uma caverna misteriosa onde vive um velho muito esquisito." },
  ["5D:6B9F"] = { "Você ganhou um Pão!" },
  ["5D:6BB8"] = { "Você ganhou um Leite!" },
  ["5D:6BD0"] = { "Você ganhou a Insígnia do Superpoder!" },
  ["5D:6BF3"] = { "Este tesouro vai ser mais útil para você. Você ganhou uma Pedra do Olho!" },
  ["5D:6C42"] = { "Você ganhou a Insígnia da Defesa!" },

  -- Fase 13: Gruta das Flores
  ["5D:6C68"] = { "Deixe-me cuidar de vocês!" },
  ["5D:6C8D"] = { "Minha flauta foi roubada por aqueles monstros. Você pode me ajudar a recuperá-la? Você ganhou a Insígnia da Agilidade!" },
  ["5D:6CF2"] = { "Você ganhou uma Pedra do Olho!" },
  ["5D:6D0F"] = { "Você ganhou um Mel!" },
  ["5D:6D28"] = { "Você ganhou a Insígnia da Força!" },
  ["5D:6D51"] = {
    "Você ganhou a Flauta Milagrosa!",
    "Obrigado! Oh! Se você precisa tanto da flauta, eu a empresto. Só não se esqueça de devolver.",
    "Bum! Eu sou muito forte, deixe-me ajudar! Rhyhorn entrou no time!",
    "Posso ir com vocês? Que emoção! Chansey entrou no time!",
  },

  -- Fase 14: Cidade Cesta de Flores
  ["5D:6E76"] = { "Deixe-me cuidar de vocês!" },
  ["5D:6E9B"] = { "Que coragem a sua! Isto é para você! Você ganhou uma Pedra do Espírito!" },
  ["5D:6EE1"] = { "Hmm... você se esforça muito. Tome um presente! Você ganhou a Insígnia do Equilíbrio!" },
  ["5D:6F37"] = { "Você ganhou uma Pedra da Fênix!" },
  ["5D:6F57"] = { "Você ganhou um Doce!" },
  ["5D:6F69"] = { "Você ganhou um Suco!" },
  ["5D:6F82"] = { "Dizem que a Flauta Milagrosa está numa certa caverna. Vá à Cidade Cesta de Flores para saber mais." },
  ["5D:6FFF"] = { "Você ganhou a Insígnia da Defesa!" },

  -- Fase 15: Usina Abandonada
  ["5D:7025"] = { "Deixe-me cuidar de vocês!" },
  ["5D:704A"] = { "Vou lhe contar um segredo: a Flauta Milagrosa é o único tesouro capaz de abrir caminho na Torre da Combustão!" },
  ["5D:70CA"] = { "Você ganhou uma Pedra das Chamas!" },
  ["5D:70EA"] = { "Você ganhou um Bolo!" },
  ["5D:7102"] = { "Você ganhou uma Pedra do Voo!" },
  ["5D:7119"] = { "Dizem que há um demônio do trovão na usina. Você me ajuda a investigar? Você ganhou a Insígnia do Equilíbrio!" },
  ["5D:71A4"] = {
    "Você ganhou a Insígnia da Agilidade!",
    "Aaaaah... Hã? O que aconteceu? Por que estou aqui? Eu estava sendo controlado? Sério?",
  },

  -- Fase 16: Torre da Combustão (exige a Flauta Milagrosa)
  ["5D:720E"] = { "Deixe-me cuidar de vocês!" },
  ["5D:7233"] = { "Há meses sofremos com o calor e a destruição. Você pode pedir ajuda ao ser que vive na torre? Você ganhou a Insígnia da Força!" },
  ["5D:72C8"] = { "Você ganhou um Pão!" },
  ["5D:72E1"] = { "Você ganhou uma Pedra do Espírito!" },
  ["5D:7301"] = { "Você ganhou uma Pedra da Vida!" },
  ["5D:7321"] = { "Que delícia! Prove você também! Você ganhou um Mel!" },
  ["5D:7361"] = {
    "Você ganhou a Escama Vermelha!",
    "Desculpe! Acho que fiz muitas coisas terríveis. Quero ajudar os moradores da ilha a reconstruir a vila destruída!",
  },
  ["5D:7413"] = { ".......ZZzzzz....ZZzzzz..............ZZzzzz....ZZzzzz......." },
  ["5D:7450"] = { "Oh! Estou no seu caminho? Desculpe! Vou sair da frente agora mesmo!" },

  -- Fase 17: Planalto de Quartzo
  ["5D:7499"] = { "Deixe-me cuidar de vocês!" },
  ["5D:74BE"] = { "Dizem que um Pokémon lendário guarda a Escama Vermelha, que dá poderes misteriosos a quem a possui." },
  ["5D:7527"] = { "Está quente! Você quer? Parece ser um tesouro muito importante! Você ganhou uma Pedra das Chamas!" },
  ["5D:7590"] = { "Você ganhou um Doce!" },
  ["5D:75A2"] = { "Você ganhou uma Pedra do Voo!" },
  ["5D:75BA"] = { "Ha! Ha! Bom garoto, tome isto! Você ganhou a Insígnia do Superpoder!" },
  ["5D:75FE"] = {
    "Você ganhou a Insígnia da Agilidade!",
    "Não me subestime! Eu sou muito forte! Torchic entrou no time!",
    "Tenho uma habilidade especial e posso ajudar. Deixe-me ir junto! Wynaut entrou no time!",
  },

  -- Fase 18: Ilha Gêmeos
  ["5D:76C2"] = { "Deixe-me cuidar de vocês!" },
  ["5D:76E7"] = { "Dizem que o guarda da Cidade do Vento se interessa muito pela Escama Vermelha. Vá à Torre da Combustão atrás de informações." },
  ["5D:777B"] = { "Isto é para você! Ha, ha! Você ganhou uma Pedra das Chamas!" },
  ["5D:77B6"] = { "Você ganhou um Doce!" },
  ["5D:77C8"] = { "Você ganhou uma Pedra do Voo!" },
  ["5D:77DD"] = { "Você ganhou um Bolo!" },
  ["5D:77F7"] = { "Que delícia! Quer um também? Você ganhou um Leite!" },
  ["5D:783C"] = { "Você ganhou a Insígnia do Superpoder!" },

  -- Fase 19: Cidade do Vento (exige a Escama Vermelha)
  ["5D:7862"] = { "Deixe-me cuidar de vocês!" },
  ["5D:7887"] = { "Diz a lenda que, para ver Ho-Oh, é preciso ter o tesouro Pena Arco-Íris." },
  ["5D:78EE"] = { "Isto é muito útil. Agora é seu! Você ganhou uma Pedra do Olho!" },
  ["5D:7935"] = { "Você ganhou um Leite!" },
  ["5D:794D"] = { "Você ganhou uma Pedra da Fênix!" },
  ["5D:7970"] = { "Ouvi dizer que a Pena Arco-Íris estaria em uma certa ilha!" },
  ["5D:79C1"] = {
    "Você ganhou a Insígnia do Equilíbrio!",
    "Uuh... uuh... estou me sentindo mal no corpo inteiro. E sei que muitos outros também estão sendo controlados!",
  },
  ["5D:7A5B"] = { "Essa não é a minha adorada Escama Vermelha? Você é mesmo incrível! Está bem, vou quebrar as regras e deixar você passar!" },

  -- Fase 20: Túnel de Pedra
  ["70:4002"] = { "Deixe-me cuidar de vocês!" },
  ["70:4027"] = { "O túnel foi tomado por um monstro terrível. Você pode nos salvar? Você ganhou uma Pedra das Chamas!" },
  ["70:4093"] = { "O Dente de Dragão é a chave para a Ilha do Redemoinho. Dizem que a ilha fica perto da Vila Nova." },
  ["70:410B"] = { "Você ganhou um Mel!" },
  ["70:4124"] = { "Você ganhou um Bolo!" },
  ["70:413C"] = { "Você ganhou uma Pedra do Olho!" },
  ["70:4160"] = {
    "Você ganhou uma Pedra da Vida!",
    "Maldição... isto não acaba aqui!! Eu vou voltar. Aguardem!",
    "Bem! Deixe-me ir junto, vou dar o meu melhor! Onix entrou no time!",
  },

  -- Fase 21: Ilha Lótus Vermelho
  ["70:4219"] = { "Deixe-me cuidar de vocês!" },
  ["70:423E"] = { "Aqui perto fica a Caverna do Dragão. Dizem que o Dente de Dragão que protege a Terra Sagrada foi roubado por um monstro desconhecido." },
  ["70:42CE"] = { "Meu Deus! A Pena Arco-Íris que eu guardava foi roubada! Você me ajuda a recuperá-la? Você ganhou uma Pedra do Voo!" },
  ["70:433C"] = { "Você ganhou um Suco!" },
  ["70:4353"] = { "Você ganhou uma Pedra do Espírito!" },
  ["70:4373"] = { "Você ganhou uma Pedra do Olho!" },
  ["70:4397"] = {
    "Você ganhou uma Pedra das Chamas!",
    "Aaah... perdi! E agora, o que vocês vão fazer comigo? Não tenho medo de nada!",
  },

  -- Fase 22: Caverna do Dragão
  ["70:4411"] = { "Deixe-me cuidar de vocês!" },
  ["70:4436"] = { "O Dente de Dragão foi roubado pelos monstros enlouquecidos. Eles são muito perigosos! Você ganhou uma Pedra das Chamas!" },
  ["70:44B0"] = { "Você ganhou um Bolo!" },
  ["70:44C8"] = { "Você ganhou uma Pedra da Vida!" },
  ["70:44E6"] = { "Você ganhou uma Pedra do Espírito!" },
  ["70:4506"] = { "Você ganhou uma Pedra da Fênix!" },
  ["70:452C"] = {
    "Você ganhou o Dente de Dragão!",
    "Eu... não acredito que estava sendo controlado. Eu...",
  },

  -- Fase 23: Torre dos Pokémon
  ["70:458E"] = { "Deixe-me cuidar de vocês!" },
  ["70:45B3"] = { "Ultimamente esses monstros andam muito agressivos. Não sei o que vai acontecer. Estou muito preocupado!" },
  ["70:461E"] = { "Você ganhou um Mel!" },
  ["70:4637"] = { "Você ganhou uma Pedra do Espírito!" },
  ["70:4657"] = { "Você ganhou um Pão!" },
  ["70:4670"] = { "Você ganhou um Leite!" },
  ["70:468D"] = {
    "Você ganhou uma Pedra da Fênix!",
    "...Parece que eu fiz o que não devia... em silêncio...",
  },

  -- Fase 24: Ilha do Redemoinho (exige o Dente de Dragão)
  ["70:46EA"] = { "Deixe-me cuidar de vocês!" },
  ["70:470F"] = { "Acho que vi o monstro com a Pena Arco-Íris na ilha! Você ganhou uma Pedra do Voo!" },
  ["70:4766"] = { "Você ganhou um Bolo!" },
  ["70:477E"] = { "Você ganhou um Leite!" },
  ["70:4796"] = { "Você ganhou uma Pedra da Fênix!" },
  ["70:47B8"] = { "Lugia foi controlado e agora todos os monstros da ilha têm medo de sair. Você pode me ajudar? Você ganhou uma Pedra do Olho!" },
  ["70:4836"] = {
    "Você ganhou a Pena Arco-Íris!",
    "Ah! Obrigado! Você sabe o quanto sofremos enquanto estávamos sendo controlados?!",
  },
  ["70:48B4"] = { "Sem uma prova, você não pode entrar de jeito nenhum. Lá dentro é perigoso demais!" },
  ["70:4910"] = { "Oh! Você tem o Dente de Dragão! Então pode passar: é a relíquia sagrada reconhecida pelos guardas." },

  -- Fase 25: Torre do Sino (exige a Pena Arco-Íris); a mensagem 0 é a entrada da Equipe Rocket
  ["70:4974"] = {
    "Para impedir que o mundo seja destruído,",
    "Para garantir a paz no mundo,",
    "Para denunciar os males com amor e verdade,",
    "Vilões adoráveis e charmosos...",
    "Jessie!",
    "James!",
    "Equipe Rocket, decolando na velocidade da luz! É isso aí! Miau!",
    "Nem pense que vai atrapalhar os nossos planos, Pokémon!",
    "Temos a insígnia poderosa, ninguém pode nos deter! Ha, ha, ha!",
    "Miau! A fortuna está à nossa espera! Ha...",
    "Corram, amigos! Temos que obrigá-los a devolver o nosso treinador! E impedir que destruam a paz do mundo Pokémon!",
  },
  ["70:4B8E"] = { "Deixe-me cuidar de vocês!" },
  ["70:4BB3"] = { "Ho-Oh foi dominado por um poder maligno. Eu imploro: ajude-me a devolver ao mundo Pokémon a paz e a alegria de antes! Você ganhou uma Pedra da Vida!" },
  ["70:4C65"] = { "Você ganhou um Bolo!" },
  ["70:4C7D"] = { "Você ganhou um Mel!" },
  ["70:4C96"] = { "Você ganhou um Leite!" },
  ["70:4CB5"] = {
    "Ho-Oh despertou assim que a insígnia maligna nas mãos da Equipe Rocket se partiu!!",
    "Oh! Foram vocês, Pokémon, que me salvaram? Muito obrigado! Vocês fizeram um ótimo trabalho. Mas, antes de agradecer, vou dar uma lição nesses humanos desprezíveis! Como ousaram fazer isso comigo, Equipe Rocket? Vocês vão ver! Chama Sagrada!",
    "Aaaah... que dor! Nunca mais vamos fazer isso!",
    "Por favor, nos perdoe! Somos apenas cidadãos inocentes e bonzinhos!!",
    "Voando e voando... que sensação irritante. Miau!",
    "Todo mundo está bem!",
    "Que ótimo! Ash!",
    "Uau! Pessoal! Senti muita falta de vocês! Fico muito feliz que vieram me salvar apesar do perigo! Meus bons amigos, vamos para casa!",
  },
  ["70:4F8C"] = { "Sem a Pena Arco-Íris você não pode ver Ho-Oh!" },
  ["70:4FC4"] = { "Você pode entrar na torre. Mas se vai conseguir ver Ho-Oh em segurança, só depende de você. Tenha cuidado!" },

  -- Cidades (Prefeito e Morador: mensagens 0 e 1 do script da cidade, $3A-$3F)
  ["70:504E"] = { "Os monstros desta ilha estão sendo controlados por uma força maligna, e os treinadores foram presos num lugar desconhecido." },
  ["70:50C4"] = { "Ouvi dizer que no Monte da Lua há uma pedra mágica com poderes misteriosos." },
  ["70:5117"] = { "Se você tiver a Pedra da Lua, sugiro procurar o barqueiro na Cabana do Cabo. Talvez você encontre alguma pista." },
  ["70:5190"] = { "Treine bastante os seus Pokémon nos Ginásios. Isso ajuda muito nas batalhas." },
  ["70:51EB"] = { "Dizem que o portão da Cidade Arco-Íris é muito vigiado. Parece que só dá para entrar com o passe!" },
  ["70:5255"] = { "Dizem que o som da Flauta Milagrosa acalma os monstros enfurecidos." },
  ["70:52AB"] = { "Você está procurando a Flauta Milagrosa? Dizem que a Gruta das Flores guarda algumas pistas. Tente lá!" },
  ["70:531E"] = { "Ouvi dizer que a Escama Vermelha é preciosa para um Pokémon lendário! Parece que alguém a coleciona!" },
  ["70:538F"] = { "Os monstros saquearam todos os tesouros da nossa cidade. Agora parece que eles estão na Caverna do Dragão e na Ilha Lótus Vermelho." },
  ["70:5410"] = { "Os monstros controlados roubaram todos os itens importantes. Se você os derrotar, vai ser bem recompensado." },
  ["70:547A"] = { "Ultimamente os monstros da Torre do Sino e da Ilha do Redemoinho andam agitados. Eles rugem sem parar e atacam uns aos outros. Os moradores estão com tanto medo que nem conseguem dormir." },
  ["70:552A"] = { "O lendário Ho-Oh deveria ser um monstro muito amigável, mas ultimamente não parece. O que será que aconteceu com ele?" },

  -- Instituto do Doutor ($40): dicas (0-5) e vantagens de tipo (8)
  ["70:55AB"] = { "Cada Pokémon tem um tipo. Quem sabe usar bem as vantagens de tipo contra o inimigo vence qualquer batalha com facilidade." },
  ["70:5631"] = { "Ao subir de nível, você pode escolher um bônus de habilidade para o Pokémon. Mas, quando ele chega ao nível máximo, não sobe mais. Fique atento." },
  ["70:56D6"] = { "Cada cidade tem um Ginásio, onde você pode treinar os seus Pokémon e também ouvir as notícias dos moradores." },
  ["70:5766"] = { "Em algumas fases, sem o item importante da fase anterior, não dá para seguir para a próxima." },
  ["70:57BD"] = { "Procurando com cuidado em cada baú, vila e cabana, você encontra tesouros raros." },
  ["70:5818"] = { "As insígnias são essenciais para a evolução dos Pokémon. Depois de conseguir uma, é preciso ir à Aliança Pokémon para evoluir." },
  ["70:58AA"] = { "Agilidade vence Equilíbrio, Equilíbrio vence Força, Força vence Superpoder, Superpoder vence Defesa e Defesa vence Agilidade." },

  -- Aliança Pokémon ($41): condições de evolução (0-3) e descrições dos golpes de cura (5-12)
  ["70:5941"] = { "Se o Pokémon não vier à Aliança usar a insígnia para evoluir, ao chegar a um certo nível ele para de subir." },
  ["70:59D8"] = { "O nível máximo da primeira forma é 20, e o da segunda forma é 40." },
  ["70:5A4D"] = { "Atenção: quando o Pokémon chegar ao nível máximo, se você não o fizer evoluir, ele não vai mais subir de nível!" },
  ["70:5AF9"] = { "Se você fizer o Pokémon evoluir cedo demais, ele vai perder alguns golpes básicos. Cuidado!" },
  ["70:5B73"] = { "Recupera 150 de HP de um aliado" },
  ["70:5BA4"] = { "Recupera 300 de HP de um aliado" },
  ["70:5BD5"] = { "Recupera 400 de HP de um aliado" },
  ["70:5C06"] = { "Recupera 800 de HP de um aliado" },
  ["70:5C37"] = { "Recupera 150 do próprio HP" },
  ["70:5C61"] = { "Recupera 300 do próprio HP" },
  ["70:5C8B"] = { "Recupera 600 do próprio HP" },
  ["70:5CB5"] = { "Recupera 700 do próprio HP" },
}
