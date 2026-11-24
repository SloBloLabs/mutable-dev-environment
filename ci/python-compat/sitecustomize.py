# Loaded automatically by Python when this directory is on PYTHONPATH.
#
# Some audio-update encoders (avr_audio_bootloader/fsk, and the pinned
# stm_audio_bootloader in Parasites) call numpy.zeros((1.0 * sample_rate, 1)).
# numpy >= 1.12 rejects float array sizes, so accept them like the numpy
# releases these encoders were written for did.
try:
  import numpy
except ImportError:
  numpy = None

if numpy is not None:
  _zeros = numpy.zeros

  def _zeros_accepting_float_sizes(shape, *args, **kwargs):
    if isinstance(shape, (tuple, list)):
      shape = tuple(int(s) for s in shape)
    elif isinstance(shape, float):
      shape = int(shape)
    return _zeros(shape, *args, **kwargs)

  numpy.zeros = _zeros_accepting_float_sizes
