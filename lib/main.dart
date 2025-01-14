import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sudoku_dart/sudoku_dart.dart';

import '../database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(SudokuApp());
}

class TelaBuscaPartidas extends StatefulWidget {
  @override
  _TelaBuscaPartidasState createState() => _TelaBuscaPartidasState();
}

class _TelaBuscaPartidasState extends State<TelaBuscaPartidas> {
  List<Map<String, dynamic>> _partidas = [];
  int _nivelSelecionado = 0;

  @override
  void initState() {
    super.initState();
    _buscarPartidas();
  }

  void _buscarPartidas() async {
    final players = await DatabaseHelper.instance.getGamesGroupedByPlayer(_nivelSelecionado);

    List<Map<String, dynamic>> partidasDetalhadas = [];
    for (var player in players) {
      final partidas = await DatabaseHelper.instance.getPlayerGames(player['name'], _nivelSelecionado);
      partidasDetalhadas.add({
        'name': player['name'],
        'victories': player['victories'],
        'defeats': player['defeats'],
        'games': partidas,
      });
    }

    setState(() {
      _partidas = partidasDetalhadas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buscar Partidas'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<int>(
                  value: _nivelSelecionado,
                  items: [
                    DropdownMenuItem(value: 0, child: Text('Easy')),
                    DropdownMenuItem(value: 1, child: Text('Medium')),
                    DropdownMenuItem(value: 2, child: Text('Hard')),
                    DropdownMenuItem(value: 3, child: Text('Expert')),
                  ],
                  onChanged: (nivel) {
                    setState(() {
                      _nivelSelecionado = nivel!;
                    });
                    _buscarPartidas();
                  },
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _partidas.length,
                  itemBuilder: (context, index) {
                    final jogador = _partidas[index];
                    final nome = jogador['name'];
                    final vitorias = jogador['victories'];
                    final derrotas = jogador['defeats'];
                    final jogos = jogador['games'] as List<Map<String, dynamic>>;

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      child: ExpansionTile(
                        title: Text('$nome'),
                        subtitle: Text('Vitórias: $vitorias | Derrotas: $derrotas'),
                        children: jogos.map((jogo) {
                          final data = jogo['date'];
                          final resultado = jogo['result'] == 1 ? 'Venceu' : 'Perdeu';
                          final corResultado = jogo['result'] == 1 ? Colors.green : Colors.red;
                          return ListTile(
                            title: Text('$data'),
                            subtitle: Text(
                              'Resultado: $resultado',
                              style: TextStyle(
                                color: corResultado,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList()
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


class SudokuApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontSize: 16),
        ),
      ),
      home: SudokuHomePage(),
    );
  }
}

class SudokuHomePage extends StatefulWidget {
  @override
  _SudokuHomePageState createState() => _SudokuHomePageState();
}

class _SudokuHomePageState extends State<SudokuHomePage> {
  final TextEditingController _nicknameController = TextEditingController();
  String _dificuldade = 'easy';
  bool _jogoIniciado = false;
  Sudoku? _sudoku;
  String _nickname = '';
  final List<String> dificuldades = ['easy', 'medium', 'hard', 'expert'];
  List<List<int>> _tabuleiro = [];
  List<List<bool>> _celsPreenchidasAPI = [];
  int? _linhaSelecionada;
  int? _colunaSelecionada;
  String? _celulaSelecionada;
  Set<String> _erros = {};

  void _iniciarJogo() {
    String nickname = _nicknameController.text;

    if (nickname.isEmpty || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(nickname)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, insira um nome válido. Não é permitido o uso de caracteres especiais.')),
      );
      return;
    }

    _erros.clear();
    setState(() {
      _nickname = nickname;
      _sudoku = Sudoku.generate(Level.values.firstWhere(
              (level) => level.toString().split('.').last == _dificuldade));
      _jogoIniciado = true;
      _tabuleiro = List.generate(9, (i) {
        return _sudoku!.puzzle.sublist(i * 9, (i + 1) * 9);
      });
      _celsPreenchidasAPI = List.generate(9, (i) {
        return List.generate(9, (j) => _tabuleiro[i][j] != -1);
      });
    });
  }

  void _novoJogo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Escolha a Dificuldade'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: dificuldades.map((nivel) {
              return RadioListTile<String>(
                title: Text(nivel),
                value: nivel,
                groupValue: _dificuldade,
                onChanged: (value) {
                  setState(() {
                    _dificuldade = value!;
                  });
                  Navigator.of(context).pop();
                  _iniciarJogo();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  bool _verificarSeVenceu() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_tabuleiro[i][j] == -1 || !_jogadaValida(i, j, _tabuleiro[i][j])) {
          return false;
        }
      }
    }
    return true;
  }


  void _salvarPartida() async {
    final DateTime now = DateTime.now();
    final String data = now.toIso8601String();

    final bool finalizada = _verificarSeVenceu();

    final int resultado = finalizada ? 1 : 0;
    final String tabuleiroJson = jsonEncode(_tabuleiro);

    final Map<String, dynamic> gameData = {
      'name': _nickname,
      'result': resultado,
      'date': data,
      'level': Level.values.indexOf(
          Level.values.firstWhere((level) => level.toString().split('.').last == _dificuldade)),
      'board': tabuleiroJson,
      'completed': finalizada ? 1 : 0,
    };

    await DatabaseHelper.instance.insertGame(gameData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          finalizada
              ? 'Partida finalizada salva como vitória!'
              : 'Partida em andamento salva como derrota!',
          style: TextStyle(color: finalizada ? Colors.green : Colors.red),
        ),
      ),
    );
  }


  void _abrirTelaBusca() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TelaBuscaPartidas()),
    );
  }

  bool _jogadaValida(int linha, int coluna, int valor) {
    if (valor <= 0) return false;

    for (int i = 0; i < 9; i++) {
      if (i != coluna && _tabuleiro[linha][i] == valor) return false;
    }

    for (int i = 0; i < 9; i++) {
      if (i != linha && _tabuleiro[i][coluna] == valor) return false;
    }

    int inicioLinha = (linha ~/ 3) * 3;
    int inicioColuna = (coluna ~/ 3) * 3;
    for (int i = inicioLinha; i < inicioLinha + 3; i++) {
      for (int j = inicioColuna; j < inicioColuna + 3; j++) {
        if ((i != linha || j != coluna) && _tabuleiro[i][j] == valor) return false;
      }
    }

    return true;
  }

  void _selecionarNumero(int numero) {
    if (_linhaSelecionada != null && _colunaSelecionada != null) {
      int linha = _linhaSelecionada!;
      int coluna = _colunaSelecionada!;
      String celula = "$linha-$coluna";

      if (_jogadaValida(linha, coluna, numero)) {
        setState(() {
          _tabuleiro[linha][coluna] = numero;
          _erros.remove(celula);
          _celulaSelecionada = null;
        });
      } else {
        setState(() {
          _tabuleiro[linha][coluna] = numero;
          _erros.add(celula);
        });
      }
    }
  }

  void _apagarNumero() {
    if (_linhaSelecionada != null && _colunaSelecionada != null) {
      int linha = _linhaSelecionada!;
      int coluna = _colunaSelecionada!;
      String celula = "$linha-$coluna";

      if (!_celsPreenchidasAPI[linha][coluna]) {
        setState(() {
          _tabuleiro[linha][coluna] = -1;
          _erros.remove(celula);
          _celulaSelecionada = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não é possível apagar uma célula fixa.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sudoku'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                if (_jogoIniciado) ...[
                  Text('Bem-vindo, $_nickname', style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          flex: 2,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 9,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: 81,
                              itemBuilder: (context, index) {
                                int linha = index ~/ 9;
                                int coluna = index % 9;
                                int valor = _tabuleiro[linha][coluna];
                                String celula = "$linha-$coluna";

                                Color backgroundColor;
                                Color textColor = Colors.black;

                                if (_celsPreenchidasAPI[linha][coluna]) {
                                  backgroundColor = Colors.lightBlue[100]!;
                                } else if (_erros.contains(celula)) {
                                  backgroundColor = Colors.white;
                                  textColor = Colors.red;
                                } else if (celula == _celulaSelecionada) {
                                  backgroundColor = Colors.grey[300]!;
                                } else {
                                  backgroundColor = Colors.white;
                                }

                                return GestureDetector(
                                  onTap: _celsPreenchidasAPI[linha][coluna]
                                      ? null
                                      : () {
                                    setState(() {
                                      _linhaSelecionada = linha;
                                      _colunaSelecionada = coluna;
                                      _celulaSelecionada = celula;
                                    });
                                  },
                                  child: Container(
                                    margin: EdgeInsets.all(1.0),
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      border: Border.all(
                                        color: Colors.grey[400]!,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: valor != -1
                                          ? Text(
                                        '$valor',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: textColor,
                                        ),
                                      )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Flexible(
                          child: Column(
                            children: [
                              ...List.generate(9, (index) {
                                return ElevatedButton(
                                  onPressed: () => _selecionarNumero(index + 1),
                                  child: Text('${index + 1}'),
                                );
                              }),
                              ElevatedButton(
                                onPressed: _apagarNumero,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                ),
                                child: Text(
                                  'Apagar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _salvarPartida(),
                        child: Text('Salvar Partida'),
                      ),
                      ElevatedButton(onPressed: _novoJogo, child: Text('Novo Jogo')),
                      ElevatedButton(onPressed: _abrirTelaBusca, child: Text('Buscar Partidas')),
                    ],
                  )
                ] else ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Qual é o seu nome?', style: TextStyle(fontSize: 24), textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: TextField(
                          controller: _nicknameController,
                          decoration: InputDecoration(
                            labelText: 'Digite seu nome',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Column(
                        children: dificuldades.map((nivel) {
                          return RadioListTile<String>(
                            title: Text(nivel),
                            value: nivel,
                            groupValue: _dificuldade,
                            onChanged: (value) {
                              setState(() {
                                _dificuldade = value!;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _iniciarJogo,
                        child: Text('Iniciar Jogo'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
