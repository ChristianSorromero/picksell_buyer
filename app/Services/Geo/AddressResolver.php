<?php

namespace App\Services\Geo;

use App\Models\Geo\Barangay;
use App\Models\Geo\Municipality;
use App\Models\Geo\Province;

/**
 * Turns an address typed or picked by name ("Batangas", "City of Tanauan", "Altura Bata") into
 * PSGC codes. The address picker already sends the official names, so most addresses match
 * exactly; spelling variants ("Tanauan City", "Brgy. Altura Bata") are normalised. Metro Manila
 * is matched by region because it has districts, not provinces. Anything that does not match
 * yields null codes, which Pickrush flags for an address fix rather than guessing.
 */
class AddressResolver
{
    private const NCR_REGION = '130000000';

    private const NCR_NAMES = ['metromanila', 'ncr', 'nationalcapitalregion'];

    /** @return array{province_code: ?string, municipality_code: ?string, barangay_code: ?string} */
    public function resolve(?string $province, ?string $municipality, ?string $barangay): array
    {
        $codes = ['province_code' => null, 'municipality_code' => null, 'barangay_code' => null];

        $municipalities = Municipality::query();
        if (in_array(self::key($province), self::NCR_NAMES, true)) {
            $municipalities->where('region_code', self::NCR_REGION);
        } else {
            $provinceRow = $this->match(Province::where('kind', 'province')->get(['code', 'name']), $province);
            if (! $provinceRow) {
                return $codes;
            }
            $codes['province_code'] = $provinceRow->code;
            $municipalities->where('province_code', $provinceRow->code);
        }

        $municipalityRow = $this->match($municipalities->get(['code', 'name', 'province_code']), $municipality);
        if (! $municipalityRow) {
            return $codes;
        }
        $codes['municipality_code'] = $municipalityRow->code;
        $codes['province_code'] ??= $municipalityRow->province_code;

        $barangayRow = $this->match(Barangay::where('municipality_code', $municipalityRow->code)->get(['code', 'name']), $barangay);
        $codes['barangay_code'] = $barangayRow?->code;

        return $codes;
    }

    private function match($rows, ?string $name)
    {
        $key = self::key($name);
        if ($key === '') {
            return null;
        }
        $matches = $rows->filter(fn ($row) => self::key($row->name) === $key);
        if ($matches->isEmpty()) {
            // "Lahug" for "Lahug (Pob.)": accept the poblacion form only when it is unambiguous.
            $bare = fn (string $k) => preg_replace('/poblacion$/', '', $k);
            $matches = $rows->filter(fn ($row) => $bare(self::key($row->name)) === $bare($key));
        }

        return $matches->count() === 1 ? $matches->first() : null;
    }

    /** "City of Tanauan", "Tanauan City" and "TANAUAN" all become "tanauan". */
    public static function key(?string $name): string
    {
        $name = mb_strtolower(trim((string) $name));
        $name = strtr($name, ['ñ' => 'n', 'é' => 'e']);
        $name = preg_replace('/\((pob\.?|poblacion)\)/', 'poblacion', $name);
        $name = preg_replace('/\b(city of|municipality of|city|municipality|brgy\.?|barangay)\b/', '', $name);

        return preg_replace('/[^a-z0-9]/', '', $name);
    }
}
