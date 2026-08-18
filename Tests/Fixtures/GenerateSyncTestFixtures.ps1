$ErrorActionPreference = 'Stop'

$generatorSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public static class SyncTestFixtureGenerator
{
    private const int Ppq = 480;
    private const int TempoMicroseconds = 500000;
    private const int TicksPerSecond = 960;
    private const int TotalTicks = 28800;
    private const int LeadTicks = 1920;
    private const int ContentEndTicks = 27840;
    private const int SampleRate = 48000;

    private sealed class NoteSpan
    {
        public double Start;
        public double End;
        public int Key;
        public int Velocity;
    }

    public static void Generate(string outputDirectory)
    {
        Directory.CreateDirectory(outputDirectory);

        List<NoteSpan> notes = new List<NoteSpan>();
        List<byte> track = new List<byte>();
        AddMeta(track, 0, 0x51, new byte[] { 0x07, 0xA1, 0x20 });
        AddMeta(track, 0, 0x03, Encoding.ASCII.GetBytes("SYNC Lyrics 120 BPM Test"));
        AddMeta(track, 0, 0x58, new byte[] { 0x04, 0x02, 0x18, 0x08 });
        AddVariableLength(track, 0);
        track.Add(0xC0);
        track.Add(0x00);

        Random random = new Random(12030);
        int cursor = LeadTicks;
        int pendingDelta = LeadTicks;
        int key = 60;
        int stepIndex = 0;
        int restCount = 0;
        int quarterCount = 0;
        int eighthCount = 0;
        int[] fixedDurations = { 480, 240, 480, 240, 480, 240, 240, 480 };
        bool[] fixedRests = { false, false, true, false, false, true, false, false };
        int[] walkSteps = { -3, -2, -1, 1, 2, 3 };

        while (cursor < ContentEndTicks)
        {
            int duration;
            bool isRest;
            if (stepIndex < fixedDurations.Length)
            {
                duration = fixedDurations[stepIndex];
                isRest = fixedRests[stepIndex];
            }
            else
            {
                duration = random.Next(100) < 48 ? 240 : 480;
                isRest = random.Next(100) < 23;
            }

            if (cursor + duration > ContentEndTicks)
                duration = ContentEndTicks - cursor;
            if (duration == 480)
                quarterCount++;
            else
                eighthCount++;

            if (isRest)
            {
                pendingDelta += duration;
                restCount++;
            }
            else
            {
                key += walkSteps[random.Next(walkSteps.Length)];
                if (key < 55) key = 55 + (55 - key);
                if (key > 67) key = 67 - (key - 67);
                int velocity = 72 + random.Next(28);

                AddVariableLength(track, pendingDelta);
                track.Add(0x90);
                track.Add((byte)key);
                track.Add((byte)velocity);
                AddVariableLength(track, duration);
                track.Add(0x80);
                track.Add((byte)key);
                track.Add(0x00);

                notes.Add(new NoteSpan
                {
                    Start = cursor / (double)TicksPerSecond,
                    End = (cursor + duration) / (double)TicksPerSecond,
                    Key = key,
                    Velocity = velocity
                });
                pendingDelta = 0;
            }

            cursor += duration;
            stepIndex++;
        }

        pendingDelta += TotalTicks - cursor;
        AddMeta(track, pendingDelta, 0x2F, new byte[0]);

        string midiPath = Path.Combine(outputDirectory, "sync_test_120bpm_30s.mid");
        WriteMidi(midiPath, track);
        string wavPath = Path.Combine(outputDirectory, "sync_test_120bpm_30s.wav");
        WriteWav(wavPath, notes);

        Console.WriteLine("MIDI: " + midiPath);
        Console.WriteLine("WAV : " + wavPath);
        Console.WriteLine("Duration=30.000s Lead=2.000s Notes=" + notes.Count +
            " Rests=" + restCount + " QuarterSlots=" + quarterCount +
            " EighthSlots=" + eighthCount);
    }

    private static void AddMeta(List<byte> track, int delta, byte type, byte[] data)
    {
        AddVariableLength(track, delta);
        track.Add(0xFF);
        track.Add(type);
        AddVariableLength(track, data.Length);
        track.AddRange(data);
    }

    private static void AddVariableLength(List<byte> bytes, int value)
    {
        int buffer = value & 0x7F;
        while ((value >>= 7) > 0)
            buffer = (buffer << 8) | ((value & 0x7F) | 0x80);
        while (true)
        {
            bytes.Add((byte)buffer);
            if ((buffer & 0x80) == 0)
                break;
            buffer >>= 8;
        }
    }

    private static void WriteMidi(string path, List<byte> track)
    {
        using (FileStream stream = new FileStream(path, FileMode.Create, FileAccess.Write))
        using (BinaryWriter writer = new BinaryWriter(stream))
        {
            writer.Write(Encoding.ASCII.GetBytes("MThd"));
            WriteBigEndian(writer, 6);
            WriteBigEndian(writer, (short)0);
            WriteBigEndian(writer, (short)1);
            WriteBigEndian(writer, (short)Ppq);
            writer.Write(Encoding.ASCII.GetBytes("MTrk"));
            WriteBigEndian(writer, track.Count);
            writer.Write(track.ToArray());
        }
    }

    private static void WriteWav(string path, List<NoteSpan> notes)
    {
        int sampleCount = SampleRate * 30;
        int dataSize = sampleCount * 2;
        using (FileStream stream = new FileStream(path, FileMode.Create, FileAccess.Write))
        using (BinaryWriter writer = new BinaryWriter(stream))
        {
            writer.Write(Encoding.ASCII.GetBytes("RIFF"));
            writer.Write(36 + dataSize);
            writer.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
            writer.Write(16);
            writer.Write((short)1);
            writer.Write((short)1);
            writer.Write(SampleRate);
            writer.Write(SampleRate * 2);
            writer.Write((short)2);
            writer.Write((short)16);
            writer.Write(Encoding.ASCII.GetBytes("data"));
            writer.Write(dataSize);

            int noteIndex = 0;
            for (int sample = 0; sample < sampleCount; sample++)
            {
                double seconds = sample / (double)SampleRate;
                while (noteIndex < notes.Count && seconds >= notes[noteIndex].End)
                    noteIndex++;

                double value = 0.0;
                if (noteIndex < notes.Count && seconds >= notes[noteIndex].Start)
                {
                    NoteSpan note = notes[noteIndex];
                    double local = seconds - note.Start;
                    double remaining = note.End - seconds;
                    double envelope = Math.Min(1.0, Math.Min(local / 0.008, remaining / 0.012));
                    double frequency = 440.0 * Math.Pow(2.0, (note.Key - 69) / 12.0);
                    double amplitude = 0.22 * (note.Velocity / 100.0) * envelope;
                    value = Math.Sin(2.0 * Math.PI * frequency * local) * amplitude;
                    value += Math.Sin(4.0 * Math.PI * frequency * local) * amplitude * 0.18;
                }
                writer.Write((short)Math.Round(Math.Max(-1.0, Math.Min(1.0, value)) * 32767.0));
            }
        }
    }

    private static void WriteBigEndian(BinaryWriter writer, short value)
    {
        writer.Write((byte)((value >> 8) & 0xFF));
        writer.Write((byte)(value & 0xFF));
    }

    private static void WriteBigEndian(BinaryWriter writer, int value)
    {
        writer.Write((byte)((value >> 24) & 0xFF));
        writer.Write((byte)((value >> 16) & 0xFF));
        writer.Write((byte)((value >> 8) & 0xFF));
        writer.Write((byte)(value & 0xFF));
    }
}
'@

Add-Type -TypeDefinition $generatorSource -Language CSharp
[SyncTestFixtureGenerator]::Generate($PSScriptRoot)
