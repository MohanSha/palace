# cython: binding=True
# Python object wrappers for alure
# Copyright (C) 2019  Nguyễn Gia Phong
#
# This file is part of archaicy.
#
# archaicy is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License,
# or (at your option) any later version.
#
# archaicy is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with archaicy.  If not, see <https://www.gnu.org/licenses/>.

__doc__ = 'Wrapper for Audio Library Utilities REtooled in Cython'
__all__ = ['ALC_TRUE', 'ALC_HRTF_SOFT', 'ALC_HRTF_ID_SOFT',
           'DeviceManager', 'Device', 'Context', 'Buffer', 'Source', 'Decoder']

from typing import Any, Dict, List, Tuple

from libcpp cimport bool as boolean, nullptr
from libcpp.memory cimport shared_ptr
from libcpp.utility cimport pair
from libcpp.vector cimport vector

cimport alure

# Type aliases
Vector3 = Tuple[float, float, float]

# Cast to Python objects
ALC_TRUE = alure.ALC_TRUE
ALC_HRTF_SOFT = alure.ALC_HRTF_SOFT
ALC_HRTF_ID_SOFT = alure.ALC_HRTF_ID_SOFT


cdef vector[alure.AttributePair] mkattrs(vector[pair[int, int]] attrs):
    """Convert attribute pairs from Python object to alure format."""
    cdef vector[alure.AttributePair] attributes
    cdef alure.AttributePair pair
    for attribute, value in attrs:
        pair.mAttribute = attribute
        pair.mValue = value
        attributes.push_back(pair)  # insert a copy
    pair.mAttribute = pair.mValue = 0
    attributes.push_back(pair)  # insert a copy
    return attributes


cdef vector[float] from_vector3(alure.Vector3 v):
    """Convert alure::Vector3 to std::vector of 3 floats."""
    cdef vector[float] result
    for i in range(3): result.push_back(v[i])
    return result


cdef alure.Vector3 to_vector3(vector[float] v):
    """Convert std::vector of 3 floats to alure::Vector3."""
    return alure.Vector3(v[0], v[1], v[2])


cdef class DeviceManager:
    """Manager of Device objects and other related functionality.
    This class is a singleton, only one instance will exist in a process
    at a time.
    """
    cdef alure.DeviceManager impl

    def __init__(self):
        """Multiple calls will give the same instance as long as
        there is still a pre-existing reference to the instance,
        or else a new instance will be created.
        """
        self.impl = alure.DeviceManager.get_instance()

    def query_extension(self, name: str) -> bool:
        """Return if a non-device-specific ALC extension exists."""
        return self.impl.query_extension(name.encode())

    @property
    def device_names(self) -> Dict[str, List[str]]:
        """A dictionary of available device names
        corresponding to each type.
        """
        basic = self.impl.enumerate(alure.DeviceEnumeration.Basic)
        full = self.impl.enumerate(alure.DeviceEnumeration.Full)
        capture = self.impl.enumerate(alure.DeviceEnumeration.Capture)
        return {'basic': [name.decode() for name in basic],
                'full': [name.decode() for name in full],
                'capture': [name.decode() for name in capture]}

    @property
    def device_name_default(self) -> Dict[str, str]:
        """A dictionary of the default device name
        corresponding to each type.
        """
        return dict(
            basic=self.impl.default_device_name(
                alure.DefaultDeviceType.Basic).decode(),
            full=self.impl.default_device_name(
                alure.DefaultDeviceType.Full).decode(),
            capture=self.impl.default_device_name(
                alure.DefaultDeviceType.Capture).decode())

    def open_playback(self, name: str = '') -> Device:
        """Return the playback device given by name.

        Raise RuntimeError on failure.
        """
        device = Device()
        device.impl = self.impl.open_playback(name.encode())
        return device


cdef class Device:
    """Audio mix output, which is either a system audio output stream
    or an actual audio port.

    The with statement is supported, e.g. ::

        with device:
            ...

    is equivalent to ::

        ...
        device.close()
    """
    cdef alure.Device impl

    def __enter__(self) -> Device:
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> bool:
        self.close()

    def __lt__(self, other: Any) -> bool:
        if not isinstance(other, Device):
            return NotImplemented
        other_device: Device = other
        return self.impl < other_device.impl

    def __le__(self, other: Any) -> bool:
        if not isinstance(other, Device):
            return NotImplemented
        other_device: Device = other
        return self.impl <= other_device.impl

    def __eq__(self, other: Any) -> bool:
        if not isinstance(other, Device):
            return NotImplemented
        other_device: Device = other
        return self.impl == other_device.impl

    def __ne__(self, other: Any) -> bool:
        if not isinstance(other, Device):
            return NotImplemented
        other_device: Device = other
        return self.impl != other_device.impl

    def __gt__(self, other: Any) -> bool:
        if not isinstance(other, Device):
            return NotImplemented
        other_device: Device = other
        return self.impl > other_device.impl

    def __ge__(self, other: Any) -> bool:
        if not isinstance(other, Device):
            return NotImplemented
        other_device: Device = other
        return self.impl >= other_device.impl

    def __bool__(self) -> bool:
        return <boolean> self.impl

    @property
    def name(self) -> Dict[str, str]:
        """A dictionary of device name corresponding to each type."""
        return {'basic': self.impl.get_name(alure.PlaybackName.Basic).decode(),
                'full': self.impl.get_name(alure.PlaybackName.Full).decode()}

    def query_extension(self, name: str) -> bool:
        """Return if an ALC extension exists on this device."""
        return self.impl.query_extension(name.encode())

    @property
    def alc_version(self) -> Tuple[int, int]:
        """ALC version supported by this device."""
        cdef alure.Version version = self.impl.get_alc_version()
        return version.get_major(), version.get_minor()

    @property
    def efx_version(self) -> Tuple[int, int]:
        """EFX version supported by this device.

        If the ALC_EXT_EFX extension is unsupported,
        this will be (0, 0).
        """
        cdef alure.Version version = self.impl.get_efx_version()
        return version.get_major(), version.get_minor()

    @property
    def frequency(self):
        """Playback frequency in hertz."""
        return self.impl.get_frequency()

    @property
    def max_auxiliary_sends(self) -> int:
        """Maximum number of auxiliary source sends.

        If ALC_EXT_EFX is unsupported, this will be 0.
        """
        return self.impl.get_max_auxiliary_sends()

    @property
    def hrtf_names(self) -> List[str]:
        """List of available HRTF names, sorted as OpenAL gives them,
        such that the index of a given name is the ID to use with
        ALC_HRTF_ID_SOFT.

        If the ALC_SOFT_HRTF extension is unavailable,
        this will be an empty list.
        """
        return [name.decode() for name in self.impl.enumerate_hrtf_names()]

    @property
    def hrtf_enabled(self) -> bool:
        """Whether HRTF is enabled on the device.

        If the ALC_SOFT_HRTF extension is unavailable,
        this will return False although there could still be
        HRTF applied at a lower hardware level.
        """
        return self.impl.is_hrtf_enabled()

    @property
    def current_hrtf(self) -> str:
        """Name of the HRTF currently being used by this device.

        If HRTF is not currently enabled, this will be None.
        """
        name = self.impl.get_current_hrtf().decode()
        return name or None

    def reset(self, attrs: Dict[int, int] = {}) -> None:
        """Reset the device, using the specified attributes.

        If the ALC_SOFT_HRTF extension is unavailable,
        this will be a no-op.
        """
        self.impl.reset(mkattrs(attrs.items()))

    def create_context(self, attrs: Dict[int, int] = {}) -> Context:
        """Return a newly created Context on this device,
        using the specified attributes.

        Raise RuntimeError on failure.
        """
        context = Context()
        if attrs:
            context.impl = self.impl.create_context(mkattrs(attrs.items()))
        else:
            context.impl = self.impl.create_context()
        return context

    def pause_dsp(self) -> None:
        """Pause device processing, stopping updates for its contexts.
        Multiple calls are allowed but it is not reference counted,
        so the device will resume after one resume_dsp call.

        This requires the ALC_SOFT_pause_device extension.
        """
        self.impl.pause_dsp()

    def resume_dsp(self) -> None:
        """Resume device processing, restarting updates for its contexts.
        Multiple calls are allowed and will no-op.
        """
        self.impl.resume_dsp()

    # TODO: get clock time

    def close(self) -> None:
        """Close and free the device.  All previously-created contexts
        must first be destroyed.
        """
        self.impl.close()


cdef class Context:
    """Container maintaining the entire audio environment, its settings
    and components, e.g. sources, buffers and effects.

    The with statement is supported, for example ::

        with context:
            ...

    is equivalent to ::

        Context.make_current(context)
        ...
        Context.make_current(None)
        context.destroy()
    """
    cdef alure.Context impl

    def __enter__(self) -> Context:
        Context.make_current(self)
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> bool:
        Context.make_current(None)
        self.destroy()

    @staticmethod
    def make_current(context: Context) -> None:
        """Make the specified context current for OpenAL operations."""
        if context is None:
            alure.Context.make_current(<alure.Context> nullptr)
        else:
            alure.Context.make_current(context.impl)

    def destroy(self) -> None:
        """Destroy the context.  The context must not be current
        when this is called.
        """
        self.impl.destroy()

    def create_decoder(self, name: str) -> Decoder:
        """Return a Decoder instance for the given audio file
        or resource name.
        """
        decoder = Decoder()
        decoder.pimpl = self.impl.create_decoder(name.encode())
        return decoder

    def get_buffer(self, name: str) -> Buffer:
        """Create and cache a Buffer for the given audio file
        or resource name.  Multiple calls with the same name will
        return the same Buffer object.  Cached buffers must be
        freed using remove_buffer before destroying the context.

        If the buffer can't be loaded RuntimeError will be raised.
        """
        buffer = Buffer()
        buffer.impl = self.impl.get_buffer(name.encode())
        return buffer

    def remove_buffer(self, buffer: Buffer) -> None:
        """Delete the given cached buffer, invalidating all other
        Buffer objects with the same name.
        """
        self.impl.remove_buffer(buffer.impl)

    def create_source(self) -> Source:
        """Return a newly created Source for playing audio.
        There is no practical limit to the number of sources you may create.
        You must call Source.destroy when the source is no longer needed.
        """
        source = Source()
        source.impl = self.impl.create_source()
        return source

    def update(self) -> None:
        """Update the context and all sources belonging to this context."""
        self.impl.update()


cdef class Buffer:
    """Buffer of preloaded PCM samples coming from a Decoder."""
    cdef alure.Buffer impl

    @property
    def length(self) -> int:
        """Length of the buffer in sample frames."""
        return self.impl.get_length()

    @property
    def frequency(self) -> int:
        """Buffer's frequency in hertz."""
        return self.impl.get_frequency()

    @property
    def channel_config_name(self) -> str:
        """Buffer's sample configuration name."""
        return alure.get_channel_config_name(
            self.impl.get_channel_config()).decode()

    @property
    def sample_type_name(self) -> str:
        """Buffer's sample type name."""
        return alure.get_sample_type_name(
            self.impl.get_sample_type()).decode()


cdef class Source:
    """Sound source for playing samples."""
    cdef alure.Source impl

    def play_from_buffer(self, buffer: Buffer) -> None:
        """Play the source using a buffer.  The same buffer
        may be played from multiple sources simultaneously.
        """
        self.impl.play(buffer.impl);

    def play_from_decoder(self, decoder: Decoder,
                          chunk_len: int, queue_size: int) -> None:
        """Play the source by asynchronously streaming audio from
        a decoder.  The given decoder must NOT have its read or seek
        methods called from elsewhere while in use.

        Parameters
        ----------
        decoder : Decoder
            The decoder object to play audio from.
        chunk_len : int
            The number of sample frames to read for each chunk update.
            Smaller values will require more frequent updates and
            larger values will handle more data with each chunk.
        queue_size : int
            The number of chunks to keep queued during playback.
            Smaller values use less memory while larger values
            improve protection against underruns.
        """
        self.impl.play(decoder.pimpl, chunk_len, queue_size)

    # TODO: play from future buffer

    def stop(self) -> None:
        """Stop playback, releasing the buffer or decoder reference.
        Any pending playback from a future buffer is canceled.
        """
        self.impl.stop()

    # TODO: fade out to stop

    def pause(self) -> None:
        """Pause the source if it is playing."""
        self.impl.pause()

    def resume(self) -> None:
        """Resume the source if it is paused."""
        self.impl.resume()

    @property
    def pending(self) -> bool:
        """Whether the source is waiting to play a future buffer."""
        return self.impl.is_pending()

    @property
    def playing(self) -> bool:
        """Whether the source is currently playing."""
        return self.impl.is_playing()

    @property
    def paused(self) -> bool:
        """Whether the source is currently paused."""
        return self.impl.is_paused()

    @property
    def playing_or_pending(self) -> bool:
        """Whether the source is currently playing
        or waiting to play in a future buffer.
        """
        return self.impl.is_playing_or_pending()

    # TODO: source group

    @property
    def priority(self) -> int:
        """Playback priority (natural number).  The lowest priority
        sources will be forcefully stopped when no more mixing sources
        are available and higher priority sources are played.
        """
        return self.impl.get_priority()

    @priority.setter
    def priority(self, value: int) -> None:
        self.impl.set_priority(value)

    @property
    def offset(self) -> int:
        """Source offset in sample frames.  For streaming sources
        this will be the offset based on the decoder's read position.
        """
        return self.impl.get_sample_offset()

    @offset.setter
    def offset(self, value: int) -> None:
        self.impl.set_offset(value)

    # TODO: sample latency
    # TODO: sec offset and latency

    @property
    def looping(self) -> bool:
        """Whether the source should loop on the Buffer or Decoder
        object's loop points.
        """
        return self.impl.get_looping()

    @looping.setter
    def looping(self, value: bool) -> None:
        self.impl.set_looping(value)

    @property
    def pitch(self) -> float:
        """Linear pitch shift base, default to 1.0."""
        return self.impl.get_pitch()

    @pitch.setter
    def pitch(self, value: float) -> None:
        self.impl.set_pitch(value)

    @property
    def gain(self) -> float:
        """Base linear volume gain, default to 1.0."""
        return self.impl.get_gain()

    @gain.setter
    def gain(self, value: float) -> None:
        self.impl.set_gain(value)

    @property
    def gain_range(self) -> Tuple[float, float]:
        """Minimum and maximum gain.  The source's gain is clamped
        to this range after distance attenuation and cone attenuation
        are applied to the gain base, although before the filter
        gain adjustements.
        """
        return self.impl.get_gain_range()

    @gain_range.setter
    def gain_range(self, value: Tuple[float, float]) -> None:
        mingain, maxgain = value
        self.impl.set_gain_range(mingain, maxgain)

    @property
    def distance_range(self) -> Tuple[float, float]:
        """Reference and maximum distance the source will use for
        the current distance model. For Clamped distance models,
        the source's calculated distance is clamped to the specified
        range before applying distance-related attenuation.

        For all distance models, the reference distance is the distance
        at which the source's volume will not have any extra attenuation
        (an effective gain multiplier of 1).
        """
        return self.impl.get_distance_range()

    @distance_range.setter
    def distance_range(self, value: Tuple[float, float]) -> None:
        refdist, maxdist = value
        self.impl.set_distance_range(refdist, maxdist)

    @property
    def position(self) -> Vector3:
        """3D position of the source."""
        return from_vector3(self.impl.get_position())

    @position.setter
    def position(self, value: Vector3) -> None:
        self.impl.set_position(to_vector3(value))

    @property
    def velocity(self) -> Vector3:
        """3D velocity in units per second.  As with OpenAL,
        this does not actually alter the source's osition,
        and instead just alters the pitch as determined
        by the doppler effect.
        """
        return from_vector3(self.impl.get_velocity())

    @velocity.setter
    def velocity(self, value: Vector3) -> None:
        self.impl.set_velocity(to_vector3(value))

    @property
    def orientation(self) -> Tuple[Vector3, Vector3]:
        """3D orientation, using `at` and `up` vectors, which are
        respectively relative position and direction.

        Note: unlike the AL_EXT_BFORMAT extension this property
        comes from, this also affects the facing direction.
        """
        cdef pair[alure.Vector3, alure.Vector3] o = self.impl.get_orientation()
        return from_vector3(o.first), from_vector3(o.second)

    @orientation.setter
    def orientation(self, value: Tuple[Vector3, Vector3]) -> None:
        at, up = value
        self.impl.set_orientation(
            pair[alure.Vector3, alure.Vector3](to_vector3(at), to_vector3(up)))

    @property
    def cone_angles(self) -> Tuple[float, float]:
        """Cone inner and outer angles in degrees.

        The inner angle is the area within which the listener will
        hear the source with no extra attenuation, while the listener
        being outside of the outer angle will hear the source attenuated
        according to the outer cone gains. The area follows the facing
        direction, so for example an inner angle of 180 means the entire
        front face of the source is in the inner cone.
        """
        return self.impl.get_cone_angles()

    @cone_angles.setter
    def cone_angles(self, value: Tuple[float, float]) -> None:
        inner, outer = value
        self.impl.set_cone_angles(inner, outer)

    @property
    def outer_cone_gains(self) -> Tuple[float, float]:
        """Linear gain and gainhf multiplier when the listener is
        outside of the source's outer cone area.

        Parameters
        ----------
        gain : float
            Linear gain applying to all frequencies.
        gainhf : float
            Linear gainhf applying extra attenuation to high frequencies
            creating a low-pass effect.  It has no effect without the
            ALC_EXT_EFX extension.
        """
        return self.impl.get_outer_cone_gains()

    @outer_cone_gains.setter
    def outer_cone_gains(self, value: Tuple[float, float]) -> None:
        gain, gainhf = value
        self.impl.set_outer_cone_gains(gain, gainhf)

    @property
    def rolloff_factors(self) -> Tuple[float, float]:
        """Rolloff factor and room factor for the direct and send paths.

        This is effectively a distance scaling relative to
        the reference distance.

        Note: to disable distance attenuation for send paths,
        set room factor to 0.  The reverb engine will, by default,
        apply a more realistic room decay based on the reverb decay
        time and distance.
        """
        self.impl.get_rolloff_factors()

    @rolloff_factors.setter
    def rolloff_factors(self, value: Tuple[float, float]) -> None:
        factor, room_factor = value
        self.impl.set_rolloff_factors(factor, room_factor)

    @property
    def stereo_angles(self) -> Tuple[float, float]:
        """Left and right channel angles, in radians, when playing
        a stereo buffer or stream. The angles go counter-clockwise,
        with 0 being in front and positive values going left.

        This has no effect without the AL_EXT_STEREO_ANGLES extension.
        """
        return self.impl.get_stereo_angles()

    @stereo_angles.setter
    def stereo_angles(self, value: Tuple[float, float]) -> None:
        left, right = value
        self.impl.set_stereo_angles(left, right)

    @property
    def spatialize(self) -> bool:
        """Either `True` (the source always has 3D spatialization
        features), `False` (never has 3D spatialization features),
        or `None` (spatialization is enabled based on playing
        a mono sound or not, default).

        This has no effect without the AL_SOFT_source_spatialize extension.
        """
        cdef alure.Spatialize value = self.impl.get_3d_spatialize()
        if value == alure.Spatialize.Auto: return None
        if value == alure.Spatialize.On: return True
        return False

    @spatialize.setter
    def spatialize(self, value: bool) -> None:
        if value is None: self.impl.set_3d_spatialize(alure.Spatialize.Auto)
        if value: self.impl.set_3d_spatialize(alure.Spatialize.On)
        self.impl.set_3d_spatialize(alure.Spatialize.Off)

    def destroy(self) -> None:
        """Destroy the source, stop playback and release resources."""
        self.impl.destroy()


cdef class Decoder:
    """Audio decoder interface."""
    cdef shared_ptr[alure.Decoder] pimpl

    @property
    def frequency(self) -> int:
        """Sample frequency, in hertz, of the audio being decoded."""
        return self.pimpl.get()[0].get_frequency()

    @property
    def channel_config_name(self) -> str:
        """Name of the channel configuration of the audio being decoded."""
        return alure.get_channel_config_name(
            self.pimpl.get()[0].get_channel_config()).decode()

    @property
    def sample_type_name(self) -> str:
        """Name of the sample type of the audio being decoded."""
        return alure.get_sample_type_name(
            self.pimpl.get()[0].get_sample_type()).decode()

    @property
    def length(self) -> int:
        """Total length of the audio, in sample frames,
        falling-back to 0.  Note that if the length is 0,
        the decoder may not be used to load a Buffer.
        """
        return self.pimpl.get()[0].get_length()
