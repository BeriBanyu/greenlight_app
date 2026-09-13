import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LampScheduleScreen extends StatefulWidget {
  const LampScheduleScreen({
    super.key,
    required this.deviceId,
    required this.keyValue,
  });

  final String deviceId;
  final String keyValue;

  @override
  State<LampScheduleScreen> createState() =>
      _LampScheduleScreenState();
}

class LampScheduleInterval {
  bool enabled;
  int startHour;
  int startMinute;
  int endHour;
  int endMinute;
  int brightness;
  int fadeMinutes;

  LampScheduleInterval({
    this.enabled = true,
    this.startHour = 7,
    this.startMinute = 0,
    this.endHour = 20,
    this.endMinute = 0,
    this.brightness = 100,
    this.fadeMinutes = 30,
  });

  LampScheduleInterval copy() {
    return LampScheduleInterval(
      enabled: enabled,
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      brightness: brightness,
      fadeMinutes: fadeMinutes,
    );
  }

  String get timeRangeText {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(startHour)}:${two(startMinute)} — '
        '${two(endHour)}:${two(endMinute)}';
  }
}

class _LampScheduleScreenState
    extends State<LampScheduleScreen> {
  static const String _lampAddress = 'http://192.168.4.1';
  static const int _maxSlots = 8;

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _background = Color(0xFFF5F5F0);
  static const Color _lightGreen = Color(0xFFE8F5E9);

  bool _isLoading = true;
  bool _isSaving = false;

  String? _loadError;

  final List<LampScheduleInterval> _intervals = [];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
      _intervals.clear();
    });

    try {
      final Uri uri = Uri.parse(
        '$_lampAddress/schedule',
      );

      final http.Response response =
          await http.get(uri).timeout(
                const Duration(seconds: 7),
              );

      if (response.statusCode != 200) {
        throw Exception(
          'ESP32 вернула код ${response.statusCode}',
        );
      }

      _parseSchedule(response.body);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError =
            'ESP32 не ответила. Проверьте, что телефон '
            'подключён к Wi-Fi светильника.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError =
            'Не удалось получить расписание:\n$error';
      });
    }
  }

  void _parseSchedule(String raw) {
    _intervals.clear();

    final List<String> lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (final String line in lines) {
      final List<String> parts = line.split(',');

      if (parts.length != 7) {
        continue;
      }

      final int? enabled = int.tryParse(parts[0]);
      final int? startHour = int.tryParse(parts[1]);
      final int? startMinute = int.tryParse(parts[2]);
      final int? endHour = int.tryParse(parts[3]);
      final int? endMinute = int.tryParse(parts[4]);
      final int? brightness = int.tryParse(parts[5]);
      final int? fadeMinutes = int.tryParse(parts[6]);

      if (enabled == null ||
          startHour == null ||
          startMinute == null ||
          endHour == null ||
          endMinute == null ||
          brightness == null ||
          fadeMinutes == null) {
        continue;
      }

      final LampScheduleInterval interval =
          LampScheduleInterval(
        enabled: enabled != 0,
        startHour: startHour.clamp(0, 23).toInt(),
        startMinute: startMinute.clamp(0, 59).toInt(),
        endHour: endHour.clamp(0, 23).toInt(),
        endMinute: endMinute.clamp(0, 59).toInt(),
        brightness: brightness.clamp(0, 100).toInt(),
        fadeMinutes: fadeMinutes.clamp(0, 120).toInt(),
      );

      final bool hasContent =
          interval.enabled ||
          interval.brightness > 0 ||
          interval.fadeMinutes > 0 ||
          interval.startHour > 0 ||
          interval.startMinute > 0 ||
          interval.endHour > 0 ||
          interval.endMinute > 0;

      if (!hasContent) {
        continue;
      }

      _intervals.add(interval);

      if (_intervals.length >= _maxSlots) {
        break;
      }
    }
  }

  String _serializeSchedule() {
    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < _maxSlots; index++) {
      final LampScheduleInterval? interval =
          index < _intervals.length
              ? _intervals[index]
              : null;

      final int enabled =
          (interval?.enabled ?? false) ? 1 : 0;

      final int startHour = interval?.startHour ?? 0;
      final int startMinute = interval?.startMinute ?? 0;
      final int endHour = interval?.endHour ?? 0;
      final int endMinute = interval?.endMinute ?? 0;
      final int brightness = interval?.brightness ?? 0;
      final int fadeMinutes = interval?.fadeMinutes ?? 0;

      if (index > 0) {
        buffer.write('\n');
      }

      buffer.write(
        '$enabled,'
        '$startHour,'
        '$startMinute,'
        '$endHour,'
        '$endMinute,'
        '$brightness,'
        '$fadeMinutes',
      );
    }

    return buffer.toString();
  }

  Future<bool> _saveSchedule({
    String successMessage = 'Расписание сохранено',
  }) async {
    if (_isSaving || !mounted) {
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Uri uri = Uri.parse(
        '$_lampAddress/schedule',
      );

      final http.Response response = await http
          .post(
            uri,
            body: {
              'key': widget.keyValue,
              'data': _serializeSchedule(),
            },
          )
          .timeout(
            const Duration(seconds: 7),
          );

      if (response.statusCode == 403) {
        throw Exception(
          'Неверный ключ устройства. '
          'Отсканируйте QR-код заново.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'ESP32 вернула код ${response.statusCode}: '
          '${response.body}',
        );
      }

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(successMessage),
                ),
              ],
            ),
          ),
        );

      return true;
    } on TimeoutException {
      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
      });

      _showSaveError(
        'ESP32 не ответила. Проверьте Wi-Fi телефона.',
      );

      return false;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _isSaving = false;
      });

      _showSaveError(
        'Не удалось сохранить расписание: $error',
      );

      return false;
    }
  }

  void _showSaveError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Text(message),
          action: SnackBarAction(
            label: 'ПОВТОРИТЬ',
            textColor: Colors.white,
            onPressed: () {
              _saveSchedule();
            },
          ),
        ),
      );
  }

  void _addInterval() {
    if (_isSaving) {
      return;
    }

    if (_intervals.length >= _maxSlots) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
            content: const Text(
              'Вы уже добавили максимум 8 интервалов.',
            ),
          ),
        );

      return;
    }

    final LampScheduleInterval newInterval =
        LampScheduleInterval(
      enabled: true,
      startHour: 7,
      startMinute: 0,
      endHour: 20,
      endMinute: 0,
      brightness: 100,
      fadeMinutes: 30,
    );

    _editInterval(
      newInterval,
      insertIndex: _intervals.length,
    );
  }

  Future<void> _editExisting(int index) async {
    if (_isSaving) {
      return;
    }

    await _editInterval(
      _intervals[index],
      insertIndex: index,
    );
  }

  Future<void> _editInterval(
    LampScheduleInterval interval, {
    required int insertIndex,
  }) async {
    final LampScheduleInterval draft = interval.copy();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _background,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            String two(int value) =>
                value.toString().padLeft(2, '0');

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom +
                    24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: _lightGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            insertIndex < _intervals.length
                                ? 'Изменить интервал'
                                : 'Новый интервал',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                      child: SwitchListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 3,
                        ),
                        value: draft.enabled,
                        activeColor: _primary,
                        title: const Text(
                          'Интервал активен',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          draft.enabled
                              ? 'Светильник будет работать '
                                  'по этому интервалу'
                              : 'Интервал сохранится, '
                                  'но выполняться не будет',
                        ),
                        onChanged: (bool value) {
                          setSheetState(() {
                            draft.enabled = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Время работы',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeButton(
                            label: 'Начало',
                            time:
                                '${two(draft.startHour)}:'
                                '${two(draft.startMinute)}',
                            icon: Icons.wb_sunny_outlined,
                            onPressed: () async {
                              final TimeOfDay? picked =
                                  await showTimePicker(
                                context: sheetContext,
                                initialTime: TimeOfDay(
                                  hour: draft.startHour,
                                  minute:
                                      draft.startMinute,
                                ),
                                helpText:
                                    'ВРЕМЯ ВКЛЮЧЕНИЯ',
                                confirmText: 'ГОТОВО',
                                cancelText: 'ОТМЕНА',
                              );

                              if (picked == null) {
                                return;
                              }

                              setSheetState(() {
                                draft.startHour =
                                    picked.hour;
                                draft.startMinute =
                                    picked.minute;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeButton(
                            label: 'Окончание',
                            time:
                                '${two(draft.endHour)}:'
                                '${two(draft.endMinute)}',
                            icon:
                                Icons.nights_stay_outlined,
                            onPressed: () async {
                              final TimeOfDay? picked =
                                  await showTimePicker(
                                context: sheetContext,
                                initialTime: TimeOfDay(
                                  hour: draft.endHour,
                                  minute: draft.endMinute,
                                ),
                                helpText:
                                    'ВРЕМЯ ВЫКЛЮЧЕНИЯ',
                                confirmText: 'ГОТОВО',
                                cancelText: 'ОТМЕНА',
                              );

                              if (picked == null) {
                                return;
                              }

                              setSheetState(() {
                                draft.endHour =
                                    picked.hour;
                                draft.endMinute =
                                    picked.minute;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Максимальная яркость',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${draft.brightness}%',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: draft.brightness.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: _primary,
                      label: '${draft.brightness}%',
                      onChanged: (double value) {
                        setSheetState(() {
                          draft.brightness =
                              value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Рассвет и закат',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '${draft.fadeMinutes} мин',
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Время плавного увеличения и уменьшения '
                      'яркости.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                    Slider(
                      value: draft.fadeMinutes.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      activeColor: _primary,
                      label: '${draft.fadeMinutes} мин',
                      onChanged: (double value) {
                        setSheetState(() {
                          draft.fadeMinutes =
                              value.round();
                        });
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext)
                                    .pop();
                              },
                              style:
                                  OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(
                                  color: _primary,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    15,
                                  ),
                                ),
                              ),
                              child: const Text('Отмена'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: () async {
                                setState(() {
                                  if (insertIndex <
                                      _intervals.length) {
                                    _intervals[
                                        insertIndex] = draft;
                                  } else {
                                    _intervals.add(draft);
                                  }
                                });

                                Navigator.of(sheetContext)
                                    .pop();

                                await _saveSchedule(
                                  successMessage:
                                      insertIndex <
                                              _intervals
                                                      .length -
                                                  1
                                          ? 'Интервал изменён '
                                              'и сохранён'
                                          : 'Интервал добавлен '
                                              'и сохранён',
                                );
                              },
                              style:
                                  FilledButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor:
                                    Colors.white,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    15,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Сохранить',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeEnabled(
    int index,
    bool enabled,
  ) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _intervals[index].enabled = enabled;
    });

    await _saveSchedule(
      successMessage: enabled
          ? 'Интервал включён'
          : 'Интервал выключен',
    );
  }

  Future<void> _removeInterval(int index) async {
    if (_isSaving) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 42,
          ),
          title: const Text('Удалить интервал?'),
          content: Text(
            'Интервал ${index + 1} будет удалён '
            'из расписания светильника.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _intervals.removeAt(index);
    });

    await _saveSchedule(
      successMessage: 'Интервал удалён',
    );
  }

  @override
  Widget build(BuildContext context) {
    final int remaining =
        _maxSlots - _intervals.length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Расписание',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ||
                _isSaving ||
                remaining <= 0
            ? null
            : _addInterval,
        backgroundColor: remaining > 0
            ? _primary
            : Colors.grey.shade400,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          remaining > 0
              ? 'Добавить'
              : 'Все интервалы заняты',
        ),
      ),
      body: Column(
        children: [
          if (_isSaving)
            const LinearProgressIndicator(
              color: _primary,
              backgroundColor: _lightGreen,
            ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _primary,
        ),
      );
    }

    if (_loadError != null) {
      return _buildErrorState();
    }

    final int remaining =
        _maxSlots - _intervals.length;

    if (_intervals.isEmpty) {
      return _buildEmptyState(remaining);
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: _loadSchedule,
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          100,
        ),
        itemCount: _intervals.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(remaining);
          }

          final int intervalIndex = index - 1;

          return _buildIntervalCard(
            intervalIndex,
            _intervals[intervalIndex],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(int remaining) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          28,
          28,
          28,
          100,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: const BoxDecoration(
                color: _lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 56,
                color: _primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Расписание не настроено',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Вы можете добавить до $_maxSlots интервалов '
              'работы светильника.\n'
              'Доступно: $remaining.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _addInterval,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Добавить первый интервал',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int remaining) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _primary,
            size: 27,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Добавлено: ${_intervals.length} '
                  'из $_maxSlots',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remaining > 0
                      ? 'Можно добавить ещё: $remaining'
                      : 'Достигнуто максимальное количество',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving)
            const SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _primary,
              ),
            )
          else
            const Icon(
              Icons.cloud_done_outlined,
              color: _primary,
            ),
        ],
      ),
    );
  }

  Widget _buildIntervalCard(
    int index,
    LampScheduleInterval interval,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      color: Colors.white,
      elevation: 1,
      shadowColor:
          const Color.fromRGBO(0, 0, 0, 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isSaving
            ? null
            : () => _editExisting(index),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            17,
            15,
            8,
            15,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: interval.enabled
                      ? _lightGreen
                      : Colors.grey.shade200,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: interval.enabled
                      ? _primary
                      : Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Интервал ${index + 1}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: interval.enabled
                                ? _lightGreen
                                : Colors.grey.shade200,
                            borderRadius:
                                BorderRadius.circular(
                              100,
                            ),
                          ),
                          child: Text(
                            interval.enabled
                                ? 'Активен'
                                : 'Выключен',
                            style: TextStyle(
                              color: interval.enabled
                                  ? _primary
                                  : Colors.grey.shade600,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      interval.timeRangeText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Яркость ${interval.brightness}%  •  '
                      'Переход ${interval.fadeMinutes} мин',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: interval.enabled,
                    activeColor: _primary,
                    onChanged: _isSaving
                        ? null
                        : (bool value) {
                            _changeEnabled(
                              index,
                              value,
                            );
                          },
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => _removeInterval(
                              index,
                            ),
                    tooltip: 'Удалить',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.red,
                size: 47,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Не удалось загрузить расписание',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 11),
            Text(
              _loadError ??
                  'Неизвестная ошибка соединения',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 25),
            FilledButton.icon(
              onPressed: _loadSchedule,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
              ),
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.time,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF2E7D32);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        side: const BorderSide(
          color: Color(0xFFB7CBB8),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            time,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}